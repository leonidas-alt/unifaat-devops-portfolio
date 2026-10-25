#!/usr/bin/env bash
# =============================================================================
# ecr-push.sh — Build e push da imagem TechNova API para o Amazon ECR
#
# Uso:
#   chmod +x ecr-push.sh
#   ./ecr-push.sh
#
# Pré-requisitos:
#   - AWS CLI v2 instalado e configurado (credenciais do Learner Lab)
#   - Docker em execução
#   - (Opcional) git tag v*.*.* para habilitar tags semver
#
# Variáveis de ambiente opcionais:
#   AWS_ACCOUNT_ID  — ID da conta AWS (detectado automaticamente se omitido)
#   AWS_REGION      — Região (padrão: us-east-1)
#   REPO_NAME       — Nome do repositório ECR (padrão: technova-api)
# =============================================================================
set -euo pipefail

# ── Configurações ─────────────────────────────────────────────────────────────
AWS_REGION="${AWS_REGION:-us-east-1}"
REPO_NAME="${REPO_NAME:-technova-api}"

# ── Cores para output ─────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log()  { echo -e "${BLUE}[INFO]${NC}  $*"; }
ok()   { echo -e "${GREEN}[OK]${NC}    $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC}  $*"; }
err()  { echo -e "${RED}[ERROR]${NC} $*" >&2; }

# ── 1. Detectar Account ID ────────────────────────────────────────────────────
log "Detectando AWS Account ID..."
AWS_ACCOUNT_ID="${AWS_ACCOUNT_ID:-$(aws sts get-caller-identity \
  --query Account --output text 2>/dev/null)}"

if [[ -z "$AWS_ACCOUNT_ID" ]]; then
  err "Não foi possível detectar o AWS Account ID."
  err "Verifique suas credenciais com: aws sts get-caller-identity"
  exit 1
fi

ECR_REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
ECR_REPO_URI="${ECR_REGISTRY}/${REPO_NAME}"

ok "Account ID : ${AWS_ACCOUNT_ID}"
ok "Registry   : ${ECR_REGISTRY}"
ok "Repositório: ${REPO_NAME}"

# ── 2. Criar repositório ECR (idempotente) ────────────────────────────────────
log "Garantindo existência do repositório ECR '${REPO_NAME}'..."

if aws ecr describe-repositories \
     --repository-names "${REPO_NAME}" \
     --region "${AWS_REGION}" \
     --query 'repositories[0].repositoryName' \
     --output text 2>/dev/null | grep -q "${REPO_NAME}"; then
  ok "Repositório '${REPO_NAME}' já existe — pulando criação."
else
  log "Criando repositório '${REPO_NAME}'..."
  aws ecr create-repository \
    --repository-name "${REPO_NAME}" \
    --region "${AWS_REGION}" \
    --image-scanning-configuration scanOnPush=true \
    --tags Key=Project,Value=TechNova Key=ManagedBy,Value=ecr-push-sh \
    --output json | jq -r '"Criado: " + .repository.repositoryUri' 2>/dev/null \
    || ok "Repositório criado com sucesso."

  # ── Lifecycle policy (mantém as 10 imagens tagged mais recentes;
  #    expira imagens untagged após 1 dia) ──────────────────────────────────────
  log "Aplicando lifecycle policy..."
  aws ecr put-lifecycle-policy \
    --repository-name "${REPO_NAME}" \
    --region "${AWS_REGION}" \
    --lifecycle-policy-text '{
      "rules": [
        {
          "rulePriority": 1,
          "description": "Expirar imagens untagged apos 1 dia",
          "selection": {
            "tagStatus": "untagged",
            "countType": "sinceImagePushed",
            "countUnit": "days",
            "countNumber": 1
          },
          "action": { "type": "expire" }
        },
        {
          "rulePriority": 2,
          "description": "Manter apenas as 10 imagens mais recentes",
          "selection": {
            "tagStatus": "tagged",
            "tagPrefixList": ["sha-", "v"],
            "countType": "imageCountMoreThan",
            "countNumber": 10
          },
          "action": { "type": "expire" }
        }
      ]
    }' > /dev/null
  ok "Lifecycle policy aplicada."
fi

# ── 3. Login no ECR ───────────────────────────────────────────────────────────
log "Autenticando Docker no ECR..."
aws ecr get-login-password --region "${AWS_REGION}" \
  | docker login \
      --username AWS \
      --password-stdin "${ECR_REGISTRY}"
ok "Login realizado."

# ── 4. Calcular tags ──────────────────────────────────────────────────────────
# Tag sha: sha-<7 primeiros caracteres do commit>
GIT_SHA_SHORT=$(git rev-parse --short=7 HEAD 2>/dev/null || echo "no-git")
SHA_TAG="sha-${GIT_SHA_SHORT}"

log "SHA do commit : ${GIT_SHA_SHORT}"

# Tags semver a partir de git tag v*.*.*  (ex.: v1.2.3 → 1.2.3, 1.2, 1)
SEMVER_TAGS=()
GIT_TAG=$(git describe --tags --exact-match HEAD 2>/dev/null || echo "")

if [[ "$GIT_TAG" =~ ^v([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
  MAJOR="${BASH_REMATCH[1]}"
  MINOR="${BASH_REMATCH[2]}"
  PATCH="${BASH_REMATCH[3]}"
  SEMVER_TAGS=("${MAJOR}.${MINOR}.${PATCH}" "${MAJOR}.${MINOR}" "${MAJOR}")
  ok "Git tag detectada: ${GIT_TAG} → semver: ${SEMVER_TAGS[*]}"
else
  warn "Nenhuma git tag semver encontrada no commit atual."
  warn "Para publicar tags semver, crie uma tag: git tag v1.0.0"
fi

# ── 5. Build da imagem ────────────────────────────────────────────────────────
log "Construindo imagem Docker (multi-stage)..."
docker build \
  --tag "${ECR_REPO_URI}:${SHA_TAG}" \
  --tag "${ECR_REPO_URI}:latest" \
  --label "git.commit=${GIT_SHA_SHORT}" \
  --label "build.date=$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --file Dockerfile \
  .
ok "Build concluído: ${ECR_REPO_URI}:${SHA_TAG}"

# Aplicar tags semver localmente (antes do push)
for TAG in "${SEMVER_TAGS[@]:-}"; do
  [[ -z "$TAG" ]] && continue
  docker tag "${ECR_REPO_URI}:${SHA_TAG}" "${ECR_REPO_URI}:${TAG}"
  ok "Tag aplicada localmente: ${TAG}"
done

# ── 6. Push das imagens ───────────────────────────────────────────────────────
log "Publicando no ECR..."

push_tag() {
  local tag="$1"
  log "  → Publicando tag: ${tag}"
  docker push "${ECR_REPO_URI}:${tag}"
  ok "  ✓ Publicado: ${ECR_REPO_URI}:${tag}"
}

push_tag "${SHA_TAG}"
push_tag "latest"

for TAG in "${SEMVER_TAGS[@]:-}"; do
  [[ -z "$TAG" ]] && continue
  push_tag "${TAG}"
done

# ── 7. Resumo final ───────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}══════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}  Push concluído com sucesso!${NC}"
echo -e "${GREEN}══════════════════════════════════════════════════════════${NC}"
echo ""
echo "  Repositório : ${ECR_REPO_URI}"
echo "  Tags publicadas:"
echo "    • ${SHA_TAG}   (rastreável por commit)"
echo "    • latest       (conveniência)"
for TAG in "${SEMVER_TAGS[@]:-}"; do
  [[ -z "$TAG" ]] && continue
  echo "    • ${TAG}          (semver)"
done
echo ""
echo "  Para fazer pull (rollback):"
echo "    docker pull ${ECR_REPO_URI}:${SHA_TAG}"
echo ""
echo "  Para ver tags no console ECR:"
echo "    https://console.aws.amazon.com/ecr/repositories/${REPO_NAME}"
echo ""
