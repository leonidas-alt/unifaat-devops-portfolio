#!/usr/bin/env bash
# =============================================
# capturar-evidencias.sh — Aula 04: VPC + EC2
# TechNova — Emilly Santos de Oliveira (4023575)
# =============================================
# Execute APÓS terraform apply:
#   chmod +x capturar-evidencias.sh
#   ./capturar-evidencias.sh
# =============================================

set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EVIDENCIAS="$DIR/evidencias"
mkdir -p "$EVIDENCIAS"

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

info()    { echo -e "${GREEN}[✔]${NC} $*"; }
warn()    { echo -e "${YELLOW}[!]${NC} $*"; }
section() { echo -e "\n${YELLOW}══ $* ══${NC}"; }

# ── 0. Verificar pré-requisitos ───────────────
section "Verificando pré-requisitos"
for cmd in terraform aws curl ssh jq; do
  command -v "$cmd" &>/dev/null && info "$cmd encontrado" || { warn "$cmd não encontrado — algumas evidências podem falhar"; }
done

# ── 1. terraform show (estado atual) ─────────
section "1. Terraform State"
cd "$DIR"
terraform show -no-color > "$EVIDENCIAS/terraform-show.txt" 2>&1
info "State salvo em evidencias/terraform-show.txt"

# ── 2. terraform output ───────────────────────
section "2. Terraform Outputs"
terraform output -no-color > "$EVIDENCIAS/terraform-outputs.txt" 2>&1
info "Outputs salvos em evidencias/terraform-outputs.txt"

# Pega o IP público diretamente do output
EC2_IP=$(terraform output -raw ec2_public_ip 2>/dev/null || echo "")
API_URL=$(terraform output -raw api_url 2>/dev/null || echo "")
SSH_CMD=$(terraform output -raw ssh_command 2>/dev/null || echo "")
KEY_FILE="$DIR/technova-key.pem"

if [[ -z "$EC2_IP" ]]; then
  warn "Não foi possível obter ec2_public_ip do output. Verifique se o apply foi executado."
  exit 1
fi

info "EC2 IP: $EC2_IP"
info "API URL: $API_URL"

# ── 3. Aguardar API ficar disponível ─────────
section "3. Aguardando API na porta 3000"
echo "Aguardando API em $API_URL (máx 3 min)..."
for i in $(seq 1 18); do
  if curl -sf --connect-timeout 3 "$API_URL" > /dev/null 2>&1; then
    info "API respondeu após $((i * 10))s"
    break
  fi
  echo "  Tentativa $i/18 — aguardando 10s..."
  sleep 10
done

# ── 4. curl na API ────────────────────────────
section "4. Evidência da API (curl)"
echo "--- GET $API_URL ---" > "$EVIDENCIAS/evidencia-api.txt"
curl -s "$API_URL" | tee -a "$EVIDENCIAS/evidencia-api.txt" | jq . 2>/dev/null || true
echo "" >> "$EVIDENCIAS/evidencia-api.txt"

echo "--- GET $API_URL/health ---" >> "$EVIDENCIAS/evidencia-api.txt"
curl -s "$API_URL/health" | tee -a "$EVIDENCIAS/evidencia-api.txt" | jq . 2>/dev/null || true
echo "" >> "$EVIDENCIAS/evidencia-api.txt"

echo "--- GET $API_URL/info ---" >> "$EVIDENCIAS/evidencia-api.txt"
curl -s "$API_URL/info" | tee -a "$EVIDENCIAS/evidencia-api.txt" | jq . 2>/dev/null || true
info "Respostas da API salvas em evidencias/evidencia-api.txt"

# ── 5. SSH na instância ───────────────────────
section "5. Evidência SSH"
if [[ -f "$KEY_FILE" ]]; then
  SSH_OPTS="-i $KEY_FILE -o StrictHostKeyChecking=no -o ConnectTimeout=10"
  {
    echo "=== Conexão SSH: ec2-user@$EC2_IP ==="
    echo "--- node --version ---"
    ssh $SSH_OPTS "ec2-user@$EC2_IP" "node --version" 2>&1

    echo "--- npm --version ---"
    ssh $SSH_OPTS "ec2-user@$EC2_IP" "npm --version" 2>&1

    echo "--- systemctl status technova-api ---"
    ssh $SSH_OPTS "ec2-user@$EC2_IP" "systemctl status technova-api --no-pager" 2>&1

    echo "--- tail /var/log/user-data.log ---"
    ssh $SSH_OPTS "ec2-user@$EC2_IP" "tail -20 /var/log/user-data.log" 2>&1

    echo "--- uptime e hostname ---"
    ssh $SSH_OPTS "ec2-user@$EC2_IP" "uptime && hostname" 2>&1
  } > "$EVIDENCIAS/evidencia-ssh.txt" 2>&1
  info "Evidência SSH salva em evidencias/evidencia-ssh.txt"
else
  warn "Chave $KEY_FILE não encontrada — pulando evidência SSH"
fi

# ── 6. aws ec2 describe-instances ─────────────
section "6. Evidência AWS CLI (describe-instances)"
aws ec2 describe-instances \
  --filters "Name=tag:Project,Values=TechNova" "Name=instance-state-name,Values=running" \
  --query 'Reservations[*].Instances[*].{ID:InstanceId,IP:PublicIpAddress,AZ:Placement.AvailabilityZone,State:State.Name,Type:InstanceType}' \
  --output table \
  > "$EVIDENCIAS/evidencia-ec2-aws-cli.txt" 2>&1
info "Descrição da instância salva em evidencias/evidencia-ec2-aws-cli.txt"

# ── 7. aws ec2 describe-vpcs e subnets ────────
section "7. Evidência da VPC e Subnets"
{
  echo "=== VPCs TechNova ==="
  aws ec2 describe-vpcs \
    --filters "Name=tag:Project,Values=TechNova" \
    --query 'Vpcs[*].{ID:VpcId,CIDR:CidrBlock,State:State}' \
    --output table

  echo ""
  echo "=== Subnets TechNova ==="
  aws ec2 describe-subnets \
    --filters "Name=tag:Project,Values=TechNova" \
    --query 'Subnets[*].{ID:SubnetId,CIDR:CidrBlock,AZ:AvailabilityZone,Public:MapPublicIpOnLaunch}' \
    --output table
} > "$EVIDENCIAS/evidencia-vpc-subnets.txt" 2>&1
info "VPC e Subnets salvos em evidencias/evidencia-vpc-subnets.txt"

# ── 8. Resumo final ───────────────────────────
section "Resumo das Evidências Coletadas"
echo ""
ls -lh "$EVIDENCIAS/"
echo ""
info "Todas as evidências salvas em: $EVIDENCIAS/"
echo ""
echo "Próximos passos:"
echo "  1. Revise os arquivos em evidencias/"
echo "  2. Atualize o entrega.md com os conteúdos"
echo "  3. Execute terraform destroy quando terminar"
echo "  4. Faça commit: git add evidencias/ && git commit -m 'feat(aula-04): evidencias de execucao'"
