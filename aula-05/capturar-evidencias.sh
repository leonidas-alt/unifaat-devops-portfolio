#!/usr/bin/env bash
# =============================================
# capturar-evidencias.sh — Aula 05: RDS + Remote State
# TechNova — Emilly Santos de Oliveira (4023575)
# =============================================
# Execute APÓS terraform apply:
#   chmod +x capturar-evidencias.sh
#   ./capturar-evidencias.sh
#
# O script captura TUDO automaticamente e salva em evidencias/
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
erro()    { echo -e "${RED}[✘]${NC} $*"; }
section() { echo -e "\n${YELLOW}══════════════════════════════════${NC}"; \
            echo -e "${YELLOW}  $*${NC}"; \
            echo -e "${YELLOW}══════════════════════════════════${NC}"; }

# ─────────────────────────────────────────────
# 0. PRÉ-REQUISITOS
# ─────────────────────────────────────────────
section "0. Verificando pré-requisitos"

for cmd in terraform aws ssh; do
  command -v "$cmd" &>/dev/null \
    && info "$cmd encontrado" \
    || { erro "$cmd não encontrado — instale antes de continuar"; exit 1; }
done

cd "$DIR"

if ! terraform output &>/dev/null 2>&1; then
  erro "terraform output falhou. Execute 'terraform apply' antes deste script."
  exit 1
fi

# ─────────────────────────────────────────────
# EXTRAI VARIÁVEIS DOS OUTPUTS
# ─────────────────────────────────────────────
EC2_IP=$(terraform output -raw ec2_public_ip)
RDS_HOST=$(terraform output -raw rds_address)
RDS_PORT=$(terraform output -raw rds_port)
RDS_DB=$(terraform output -raw rds_db_name)
RDS_ID=$(terraform output -raw rds_identifier)
KEY_FILE="$DIR/technova-key.pem"
SSH_OPTS="-i $KEY_FILE -o StrictHostKeyChecking=no -o ConnectTimeout=15 -o BatchMode=yes"

# Tenta pegar o bucket do output do backend
BUCKET=""
if terraform -chdir=backend output bucket_name &>/dev/null 2>&1; then
  BUCKET=$(terraform -chdir=backend output -raw bucket_name 2>/dev/null || echo "")
fi

info "EC2 IP:     $EC2_IP"
info "RDS Host:   $RDS_HOST"
info "RDS Porta:  $RDS_PORT"
info "Banco:      $RDS_DB"
info "Bucket S3:  ${BUCKET:-'(não disponível — verifique backend/)'}"
info "Chave SSH:  $KEY_FILE"

# ─────────────────────────────────────────────
# 1. TERRAFORM OUTPUTS
# ─────────────────────────────────────────────
section "1. Terraform Outputs"

{
  echo "============================================"
  echo " terraform output — Aula 05: RDS + Remote State"
  echo " Aluno: Emilly Santos de Oliveira | RA: 4023575"
  echo " Data: $(date '+%d/%m/%Y %H:%M:%S')"
  echo "============================================"
  echo ""
  terraform output -no-color
} > "$EVIDENCIAS/terraform-outputs.txt"

info "Salvo em evidencias/terraform-outputs.txt"

# ─────────────────────────────────────────────
# 2. STATE NO S3
# ─────────────────────────────────────────────
section "2. State no S3 (Remote State)"

if [[ -n "$BUCKET" ]]; then
  {
    echo "============================================"
    echo " Evidência: State armazenado no S3"
    echo " Bucket: $BUCKET"
    echo " Data: $(date '+%d/%m/%Y %H:%M:%S')"
    echo "============================================"
    echo ""
    echo "--- aws s3 ls s3://$BUCKET/aula-05/ ---"
    aws s3 ls "s3://${BUCKET}/aula-05/" --human-readable
    echo ""
    echo "--- Versões do state (versionamento ativo) ---"
    aws s3api list-object-versions \
      --bucket "$BUCKET" \
      --prefix "aula-05/terraform.tfstate" \
      --query 'Versions[*].{Versao:VersionId,Modificado:LastModified,Tamanho:Size}' \
      --output table 2>/dev/null || echo "(sem versões anteriores)"
    echo ""
    echo "--- Configurações do bucket ---"
    aws s3api get-bucket-versioning --bucket "$BUCKET"
    aws s3api get-bucket-encryption --bucket "$BUCKET" \
      --query 'ServerSideEncryptionConfiguration.Rules[0].ApplyServerSideEncryptionByDefault' \
      --output table 2>/dev/null || true
  } > "$EVIDENCIAS/s3-state.txt"
  info "Salvo em evidencias/s3-state.txt"
else
  warn "Bucket não encontrado no output — pulando evidência S3"
  echo "AVISO: bucket_name não encontrado no terraform output" > "$EVIDENCIAS/s3-state.txt"
  echo "Verifique se o providers.tf está com o nome real do bucket." >> "$EVIDENCIAS/s3-state.txt"
fi

# ─────────────────────────────────────────────
# 3. AGUARDA SSH FICAR DISPONÍVEL
# ─────────────────────────────────────────────
section "3. Aguardando EC2 aceitar SSH"

if [[ ! -f "$KEY_FILE" ]]; then
  erro "Chave $KEY_FILE não encontrada. O terraform apply gerou ela?"
  exit 1
fi

echo "Aguardando SSH em $EC2_IP (máx 3 min)..."
SSH_OK=false
for i in $(seq 1 18); do
  if ssh $SSH_OPTS "ec2-user@$EC2_IP" "echo ok" &>/dev/null; then
    info "SSH disponível após $((i * 10))s"
    SSH_OK=true
    break
  fi
  echo "  Tentativa $i/18 — aguardando 10s..."
  sleep 10
done

if [[ "$SSH_OK" == false ]]; then
  erro "EC2 não respondeu SSH em 3 min. Verifique o Security Group."
  exit 1
fi

# ─────────────────────────────────────────────
# 4. LOG DO TESTE RDS (gerado pelo user_data)
# ─────────────────────────────────────────────
section "4. Conexão EC2 → RDS (log do user_data)"

echo "Aguardando user_data concluir (psql + tabela orders)..."
LOG_OK=false
for i in $(seq 1 36); do
  LOG=$(ssh $SSH_OPTS "ec2-user@$EC2_IP" \
    "test -f /var/log/rds-test.log && cat /var/log/rds-test.log" 2>/dev/null || echo "")
  if echo "$LOG" | grep -q "SELECT id"; then
    info "Log completo encontrado após $((i * 10))s"
    LOG_OK=true
    break
  fi
  echo "  Aguardando log... tentativa $i/36 (máx 6 min)"
  sleep 10
done

{
  echo "============================================"
  echo " Evidência: Conexão EC2 → RDS PostgreSQL"
  echo " EC2: $EC2_IP → RDS: $RDS_HOST:$RDS_PORT"
  echo " Data: $(date '+%d/%m/%Y %H:%M:%S')"
  echo "============================================"
  echo ""

  if [[ "$LOG_OK" == true ]]; then
    echo "--- /var/log/rds-test.log (gerado automaticamente pelo user_data) ---"
    echo ""
    ssh $SSH_OPTS "ec2-user@$EC2_IP" "cat /var/log/rds-test.log"
  else
    warn "Log incompleto — capturando o que existe até agora..."
    echo "--- Log parcial ---"
    ssh $SSH_OPTS "ec2-user@$EC2_IP" \
      "cat /var/log/rds-test.log 2>/dev/null || echo 'arquivo não encontrado ainda'" || true
    echo ""
    echo "--- user-data.log (bootstrap completo) ---"
    ssh $SSH_OPTS "ec2-user@$EC2_IP" "tail -50 /var/log/user-data.log" || true
  fi
} > "$EVIDENCIAS/rds-conexao.txt"

info "Salvo em evidencias/rds-conexao.txt"

# ─────────────────────────────────────────────
# 5. TESTE DE CONEXÃO PSQL A PARTIR DO EC2
# ─────────────────────────────────────────────
section "5. Teste psql direto no EC2"

# Pega a senha do terraform.tfvars (nunca sai do ambiente local)
DB_PASS=""
if [[ -f "$DIR/terraform.tfvars" ]]; then
  DB_PASS=$(grep 'db_password' "$DIR/terraform.tfvars" | sed 's/.*=\s*"\(.*\)"/\1/' | tr -d ' ')
fi

if [[ -n "$DB_PASS" ]]; then
  {
    echo "============================================"
    echo " Evidência: psql — versão e tabela orders"
    echo " Host: $RDS_HOST | Banco: $RDS_DB"
    echo " Data: $(date '+%d/%m/%Y %H:%M:%S')"
    echo "============================================"
    echo ""

    echo "--- SELECT version() ---"
    ssh $SSH_OPTS "ec2-user@$EC2_IP" \
      "PGPASSWORD='${DB_PASS}' psql -h ${RDS_HOST} -p ${RDS_PORT} -U technova_admin -d ${RDS_DB} -c 'SELECT version();' 2>&1" \
      || echo "(falhou — RDS pode ainda estar inicializando)"

    echo ""
    echo "--- SELECT * FROM orders ---"
    ssh $SSH_OPTS "ec2-user@$EC2_IP" \
      "PGPASSWORD='${DB_PASS}' psql -h ${RDS_HOST} -p ${RDS_PORT} -U technova_admin -d ${RDS_DB} -c 'SELECT id, product, quantity, unit_price, created_at FROM orders ORDER BY id;' 2>&1" \
      || echo "(falhou — tabela pode ainda não ter sido criada)"

    echo ""
    echo "--- pg_isready (status da conexão) ---"
    ssh $SSH_OPTS "ec2-user@$EC2_IP" \
      "pg_isready -h ${RDS_HOST} -p ${RDS_PORT} -U technova_admin -d ${RDS_DB} 2>&1" \
      || echo "(pg_isready falhou)"

  } > "$EVIDENCIAS/psql-teste.txt"
  info "Salvo em evidencias/psql-teste.txt"
else
  warn "db_password não encontrado no terraform.tfvars — pulando teste psql direto"
  echo "AVISO: terraform.tfvars sem db_password — teste psql não executado" \
    > "$EVIDENCIAS/psql-teste.txt"
fi

# ─────────────────────────────────────────────
# 6. EVIDÊNCIA AWS CLI (EC2 + RDS + VPC)
# ─────────────────────────────────────────────
section "6. Recursos AWS via CLI"

{
  echo "============================================"
  echo " Evidência: Recursos AWS provisionados"
  echo " Data: $(date '+%d/%m/%Y %H:%M:%S')"
  echo "============================================"
  echo ""

  echo "--- EC2 em execução ---"
  aws ec2 describe-instances \
    --filters "Name=tag:Project,Values=TechNova" \
              "Name=instance-state-name,Values=running" \
    --query 'Reservations[*].Instances[*].{ID:InstanceId,IP:PublicIpAddress,AZ:Placement.AvailabilityZone,Estado:State.Name,Tipo:InstanceType}' \
    --output table

  echo ""
  echo "--- RDS em execução ---"
  aws rds describe-db-instances \
    --db-instance-identifier "$RDS_ID" \
    --query 'DBInstances[*].{ID:DBInstanceIdentifier,Status:DBInstanceStatus,Classe:DBInstanceClass,Engine:Engine,Versao:EngineVersion,Endpoint:Endpoint.Address,Porta:Endpoint.Port,Publico:PubliclyAccessible,Encriptado:StorageEncrypted}' \
    --output table

  echo ""
  echo "--- VPC TechNova ---"
  aws ec2 describe-vpcs \
    --filters "Name=tag:Project,Values=TechNova" \
    --query 'Vpcs[*].{ID:VpcId,CIDR:CidrBlock,Estado:State,DNS:EnableDnsHostnames}' \
    --output table

  echo ""
  echo "--- Subnets TechNova ---"
  aws ec2 describe-subnets \
    --filters "Name=tag:Project,Values=TechNova" \
    --query 'Subnets[*].{ID:SubnetId,CIDR:CidrBlock,AZ:AvailabilityZone,Publica:MapPublicIpOnLaunch}' \
    --output table

  echo ""
  echo "--- Security Groups TechNova ---"
  aws ec2 describe-security-groups \
    --filters "Name=tag:Project,Values=TechNova" \
    --query 'SecurityGroups[*].{ID:GroupId,Nome:GroupName,Descricao:Description}' \
    --output table

  echo ""
  echo "--- DynamoDB Lock Table ---"
  aws dynamodb describe-table \
    --table-name "technova-terraform-lock" \
    --query 'Table.{Nome:TableName,Status:TableStatus,Chave:KeySchema[0].AttributeName}' \
    --output table 2>/dev/null || echo "(tabela não encontrada)"

} > "$EVIDENCIAS/aws-recursos.txt"

info "Salvo em evidencias/aws-recursos.txt"

# ─────────────────────────────────────────────
# 7. TERRAFORM PLAN (deve mostrar "No changes")
# ─────────────────────────────────────────────
section "7. terraform plan (deve ser 'No changes')"

{
  echo "============================================"
  echo " Evidência: terraform plan após apply"
  echo " Esperado: 'No changes. Infrastructure is up-to-date.'"
  echo " Data: $(date '+%d/%m/%Y %H:%M:%S')"
  echo "============================================"
  echo ""
  terraform plan -no-color 2>&1
} > "$EVIDENCIAS/terraform-plan.txt"

if grep -q "No changes" "$EVIDENCIAS/terraform-plan.txt"; then
  info "terraform plan: No changes ✅"
else
  warn "terraform plan mostrou mudanças — verifique evidencias/terraform-plan.txt"
fi

# ─────────────────────────────────────────────
# RESUMO FINAL
# ─────────────────────────────────────────────
section "Evidências Coletadas com Sucesso"
echo ""
ls -lh "$EVIDENCIAS/"
echo ""
info "Todos os arquivos salvos em: $EVIDENCIAS/"
echo ""
echo -e "${YELLOW}Próximos passos:${NC}"
echo "  1. Revise os arquivos em evidencias/"
echo "  2. Cole no entrega.md os conteúdos relevantes"
echo "  3. Execute: terraform destroy"
echo "  4. Esvazie o bucket S3 e execute: cd backend/ && terraform destroy"
echo "  5. git add aula-05/ .github/ .gitignore"
echo "  6. git commit -m 'feat(aula-05): RDS + Remote State com Terraform'"
echo "  7. git push -u origin feature/aula-05-rds-remote-state"
echo ""
