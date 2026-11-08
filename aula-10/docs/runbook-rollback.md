# Runbook — Procedimento de Rollback

**Projeto:** TechNova API  
**Aula:** 10 — Terraform GitOps + CD Pipeline  
**Aluno:** Emilly Santos de Oliveira (RA: 4023575)

---

## Quando usar este runbook

Use este procedimento quando:
- O health check pós-deploy falhou no pipeline
- A API está retornando erros após um deploy
- O container novo não subiu corretamente
- Você precisa voltar para uma versão anterior com urgência

---

## Pré-requisitos

- Acesso SSH à instância EC2 (chave `.pem`)
- AWS CLI configurado com credenciais do Learner Lab
- Conhecimento do SHA da versão estável anterior

---

## 1. Identificar a versão estável anterior

### Via git log

```bash
# No repositório local
git log --oneline aula-10/ | head -10
# Anote o SHA do commit anterior ao problema
```

### Via ECR (lista imagens disponíveis)

```bash
aws ecr list-images \
  --repository-name technova-api \
  --region us-east-1 \
  --query 'imageIds[?imageTag!=`latest`].[imageTag]' \
  --output text | sort -r | head -10
```

A saída lista as tags `sha-XXXXXXX`. Identifique a tag da versão estável.

---

## 2. Fazer rollback via SSH na EC2

### 2.1 Conectar à EC2

```bash
ssh -i technova-key-aula10.pem ec2-user@<EC2_PUBLIC_IP>
```

### 2.2 Configurar variáveis

```bash
# Substitua pelos valores reais
AWS_REGION="us-east-1"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REGISTRY="${ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
ECR_REPO="technova-api"
SHA_ANTERIOR="<SHA_DO_COMMIT_ESTAVEL>"  # ex: sha-a1b2c3d

IMAGE_URI="${REGISTRY}/${ECR_REPO}:${SHA_ANTERIOR}"
CONTAINER_NAME="technova-api"
```

### 2.3 Login no ECR antes do pull

> ⚠️ Este passo é obrigatório. O token ECR expira a cada 12 horas.

```bash
aws ecr get-login-password --region "${AWS_REGION}" | \
  docker login --username AWS --password-stdin "${REGISTRY}"
```

### 2.4 Pull da imagem anterior

```bash
docker pull "${IMAGE_URI}"
```

### 2.5 Recreate com a versão anterior (Rollback)

```bash
# Para o container atual
docker stop "${CONTAINER_NAME}" || true

# Remove o container
docker rm "${CONTAINER_NAME}" || true

# Sobe a versão anterior
docker run -d \
  --name "${CONTAINER_NAME}" \
  --restart unless-stopped \
  -p 3000:3000 \
  -e NODE_ENV=production \
  "${IMAGE_URI}"
```

### 2.6 Verificar se o container está rodando

```bash
docker ps --filter "name=${CONTAINER_NAME}"
docker logs "${CONTAINER_NAME}" --tail 20
```

---

## 3. Verificar o health check

```bash
# Dentro da EC2 (loop de retry)
for i in $(seq 1 5); do
  STATUS=$(curl -s -o /tmp/health.json -w "%{http_code}" http://localhost:3000/health)
  echo "Tentativa ${i}: HTTP ${STATUS}"
  if [ "${STATUS}" = "200" ]; then
    echo "✅ API respondendo corretamente"
    cat /tmp/health.json
    break
  fi
  sleep 5
done
```

```bash
# De fora da EC2 (da sua máquina)
curl -s http://<EC2_PUBLIC_IP>:3000/health | jq .
```

Resposta esperada:

```json
{
  "status": "ok",
  "timestamp": "2026-10-25T...",
  "version": "1.0.0",
  "sha": "a1b2c3d...",
  "environment": "production"
}
```

---

## 4. Rollback de infraestrutura Terraform

Se o problema for na infraestrutura (não na aplicação):

### 4.1 Reverter o código Terraform

```bash
# No repositório local
git log --oneline aula-10/terraform/ | head -5
git revert <COMMIT_PROBLEMÁTICO>
git push origin main
# O terraform-apply.yml disparará automaticamente
```

### 4.2 Forçar apply de uma revisão anterior (emergência)

> ⚠️ Faça isso apenas como última opção — prefira sempre o revert via Git.

```bash
cd aula-10/terraform
git checkout <SHA_ESTAVEL> -- .
terraform init
terraform apply -auto-approve
```

---

## 5. Checklist pós-rollback

- [ ] Container rodando (`docker ps`)
- [ ] Health check respondendo HTTP 200 (`/health`)
- [ ] Logs sem erros críticos (`docker logs technova-api --tail 50`)
- [ ] Issue aberta no repositório documentando o incidente
- [ ] PR criado para corrigir o código que causou o problema
- [ ] Notificar o time sobre o rollback e a causa raiz

---

## 6. Causas comuns de falha e como diagnosticar

| Sintoma | Causa provável | Solução |
|---------|----------------|---------|
| `docker pull` falha | Token ECR expirado | Refazer login no ECR (passo 2.3) |
| Container sobe mas morre | Erro na aplicação | `docker logs technova-api` |
| Health check timeout | Security Group bloqueando porta 3000 | Verificar regras de entrada no SG |
| `docker: cannot connect to daemon` | Docker não está rodando | `sudo systemctl start docker` |
| `No such container` no stop/rm | Container não existia | Normal no primeiro deploy — use `|| true` |
| Credenciais AWS expiradas | Sessão do Learner Lab fechada | Reabrir o Lab e atualizar Secrets |

---

## 7. Contatos e referências

- Repositório: `unifaat-devops-portfolio/aula-10/`
- ECR Console: AWS Console → ECR → `technova-api`
- Actions: GitHub → Actions → `CD — Aula 10`
- Histórico de deploys: `git log --oneline aula-10/`
