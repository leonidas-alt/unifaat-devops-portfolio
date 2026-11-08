# Aula 10 — Terraform GitOps + CD Pipeline

**Aluno:** Emilly Santos de Oliveira  
**RA:** 4023575  
**Disciplina:** DevOps — Centro Universitário UniFAAT  
**Professor:** Alexandre Tavares  
**Semestre:** 2026-2

---

## Sobre

Implementação completa de GitOps com Terraform (plan automático em PRs e apply automático no merge) e pipeline de CD com lint → test → build → push para Amazon ECR → deploy na EC2 com estratégia Recreate e health check pós-deploy.

---

## Estrutura

```
aula-10/
├── .github/
│   └── workflows/
│       ├── terraform-plan.yml    # Plan automático em PRs
│       ├── terraform-apply.yml   # Apply automático no merge para main
│       └── cd.yml                # Pipeline CD: lint→test→build→push→deploy
├── terraform/
│   ├── provider.tf               # Provider AWS + backend S3
│   ├── variables.tf              # Variáveis de entrada
│   ├── main.tf                   # VPC, EC2, ECR, Security Group
│   └── outputs.tf                # Outputs: IP, URL, ECR URI
├── technova-api/
│   ├── server.js                 # API Express (health, products, orders)
│   ├── package.json              # Dependências e scripts
│   ├── .eslintrc.json            # Configuração ESLint
│   ├── .dockerignore             # Arquivos excluídos do contexto Docker
│   └── __tests__/
│       └── server.test.js        # Testes Jest (health + products + orders)
├── Dockerfile                    # Multi-stage: deps → builder → production
├── gitops-cd-analise.md          # Análise crítica dos conceitos
├── docs/
│   └── runbook-rollback.md       # Procedimento de rollback
├── screenshots/                  # Evidências do funcionamento
│   ├── plan-pr-comment.png
│   ├── apply-success.png
│   ├── cd-pipeline-green.png
│   └── health-check-pass.png
└── README.md                     # Este arquivo
```

---

## Pré-requisitos

- Conta AWS (Learner Lab ou real)
- Terraform >= 1.6.0
- Node.js >= 20
- Docker
- AWS CLI configurado

---

## Como reproduzir

### 1. Configurar GitHub Secrets

No repositório, vá em **Settings → Secrets → Actions** e adicione:

| Secret | Descrição |
|--------|-----------|
| `AWS_ACCESS_KEY_ID` | Access Key ID do Learner Lab |
| `AWS_SECRET_ACCESS_KEY` | Secret Access Key do Learner Lab |
| `AWS_SESSION_TOKEN` | Session Token do Learner Lab |
| `EC2_HOST` | IP público da EC2 (após apply do Terraform) |
| `EC2_USER` | Usuário SSH (ex: `ec2-user`) |
| `EC2_SSH_KEY` | Conteúdo da chave privada `.pem` |

> ⚠️ As credenciais do Learner Lab expiram a cada ~4h. Atualize-as antes de rodar os workflows.

### 2. Criar o bucket S3 para o estado do Terraform

```bash
aws s3api create-bucket \
  --bucket technova-tfstate-4023575 \
  --region us-east-1
```

### 3. Criar o Key Pair na AWS

```bash
aws ec2 create-key-pair \
  --key-name technova-key-aula10 \
  --region us-east-1 \
  --query 'KeyMaterial' \
  --output text > technova-key-aula10.pem

chmod 400 technova-key-aula10.pem
```

### 4. Testar autenticação AWS (antes de rodar os workflows)

Crie um workflow simples ou execute localmente:

```bash
aws sts get-caller-identity
```

### 5. Fazer deploy da infraestrutura via GitOps

```bash
# Crie uma branch de feature
git checkout -b feature/infra-aula10

# Modifique qualquer arquivo .tf (ex: adicione uma tag)
# Abra um PR para main

# O terraform-plan.yml vai:
# 1. Rodar fmt -check, init, validate, plan
# 2. Postar o resultado como comentário no PR

# Após aprovação, faça o merge
# O terraform-apply.yml vai aplicar automaticamente
```

### 6. Rodar a API localmente

```bash
cd technova-api
npm install
npm test        # roda os testes Jest
npm run lint    # roda o ESLint
npm start       # inicia em localhost:3000
```

```bash
# Testar os endpoints
curl http://localhost:3000/health
curl http://localhost:3000/api/products
curl http://localhost:3000/api/orders
curl -X POST http://localhost:3000/api/orders \
  -H "Content-Type: application/json" \
  -d '{"product": "Mouse Gamer", "quantity": 2}'
```

### 7. Build e push manual da imagem Docker

```bash
# Login no ECR
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin \
  <ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com

# Build (executar da pasta aula-10/)
docker build -t technova-api:local \
  -f Dockerfile \
  technova-api/

# Tag e push
docker tag technova-api:local \
  <ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com/technova-api:manual

docker push \
  <ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com/technova-api:manual
```

### 8. Deploy manual na EC2 (rollback/emergência)

Consulte o [Runbook de Rollback](docs/runbook-rollback.md) para o procedimento completo.

---

## Workflows

### `terraform-plan.yml` — Plan automático em PRs

- **Trigger:** PR aberto ou atualizado para `main` com mudanças em `aula-10/terraform/**`
- **O que faz:** fmt -check → init → validate → plan → comenta resultado no PR
- **Comportamento:** comenta é atualizado (sem duplicata) a cada novo push no PR
- **Falha:** se o plan falhar, o workflow falha e o PR fica bloqueado

### `terraform-apply.yml` — Apply automático no merge

- **Trigger:** push para `main` com mudanças em `aula-10/terraform/**`
- **O que faz:** init → validate → apply -auto-approve → captura outputs
- **Outputs:** IP da EC2, URL do ECR, URL da API visíveis no log e no Step Summary

### `cd.yml` — Pipeline CD completo

- **Trigger:** push para `main` com mudanças em `aula-10/technova-api/**` ou `aula-10/Dockerfile`
- **Jobs:**
  1. `lint` — ESLint no código da API
  2. `test` — Jest com cobertura (upload do relatório como artifact)
  3. `build-push` — Build multi-stage + push ECR com tags `sha-XXXXXXX` e `latest`
  4. `deploy` — SSH na EC2, Recreate (stop→rm→pull→run) + health check com 10 retries
- **Falha:** se o health check não responder HTTP 200 após 10 tentativas, o job falha

---

## Autenticação AWS

### Learner Lab (implementado)

```yaml
- uses: aws-actions/configure-aws-credentials@v4
  with:
    aws-access-key-id:     ${{ secrets.AWS_ACCESS_KEY_ID }}
    aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
    aws-session-token:     ${{ secrets.AWS_SESSION_TOKEN }}
    aws-region:            us-east-1
```

### Produção — padrão ideal com OIDC (referência)

Em ambientes reais fora do Learner Lab, substituir pelas 3 credenciais por OIDC + IAM Role:

```yaml
- uses: aws-actions/configure-aws-credentials@v4
  with:
    role-to-assume: arn:aws:iam::ACCOUNT_ID:role/github-actions-role
    aws-region: us-east-1
```

O Learner Lab não permite criar OIDC Providers nem IAM Roles para entidades externas, por isso usamos credenciais de sessão.

---

## Aprendizados

- **GitOps com Terraform:** plan no PR cria visibilidade antes da mudança; apply no merge garante que o repositório reflete o estado real da infraestrutura
- **Credenciais de sessão vs OIDC:** o Lab impõe limitações que, em produção, seriam resolvidas com OIDC — entender a diferença é essencial para ambientes reais
- **Estratégia Recreate:** simples e eficaz para learning, mas tem downtime — Blue-Green e Canary (aulas 11 e 12) resolvem isso
- **Health check automatizado:** pipeline só considera o deploy bem-sucedido após confirmar que a API responde — evita falsos positivos
- **Continuous Deployment:** todo merge aprovado vai automaticamente para produção — exige confiança nos testes automatizados

---

## Referências

- [Terraform GitOps com GitHub Actions](https://developer.hashicorp.com/terraform/tutorials/automation/github-actions)
- [aws-actions/configure-aws-credentials](https://github.com/aws-actions/configure-aws-credentials)
- [appleboy/ssh-action](https://github.com/appleboy/ssh-action)
- [docker/build-push-action](https://github.com/docker/build-push-action)
- [OIDC com GitHub Actions e AWS](https://docs.github.com/en/actions/security-for-github-actions/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services)
