# Aula 09 — Docker Registry e IA no CI/CD

[![CI — Aula 09](https://github.com/leonidas-alt/unifaat-devops-portfolio/actions/workflows/ci-aula09.yml/badge.svg)](https://github.com/leonidas-alt/unifaat-devops-portfolio/actions/workflows/ci-aula09.yml)

**Aluno:** Emilly Santos de Oliveira  
**RA:** 4023575  
**Disciplina:** DevOps — Centro Universitário UniFAAT  
**Professor:** Alexandre Tavares  

---

## Sobre

Pipeline completo que builda e publica a imagem Docker da TechNova API no **Amazon ECR**, e revisa automaticamente cada Pull Request com análise estática de segurança (AI Review).

---

## Estrutura

```
aula-09/
├── .github/
│   ├── workflows/
│   │   ├── ai-review.yml       # AI Review disparado em PRs
│   │   └── ci.yml              # CI: lint + test + push para ECR (main)
│   └── scripts/
│       └── ai-review.js        # Script de análise estática (13 regras)
├── screenshots/                # Evidências (preencher após execução)
├── Dockerfile                  # Multi-stage: deps → builder → production
├── .dockerignore
├── ecr-push.sh                 # Script principal: cria repo + login + build + push
├── server.js                   # TechNova API (Express)
├── package.json
├── ia-cicd-analise.md          # Análise crítica sobre ECR e IA no CI/CD
└── README.md
```

---

## Pré-requisitos

- Docker em execução
- AWS CLI v2 configurado com credenciais do Learner Lab
- Node.js >= 20
- Git

---

## Como executar localmente

### 1. Configurar credenciais do Learner Lab

No AWS Academy, copie as credenciais da sessão e exporte:

```bash
export AWS_ACCESS_KEY_ID="ASIA..."
export AWS_SECRET_ACCESS_KEY="..."
export AWS_SESSION_TOKEN="..."
export AWS_REGION="us-east-1"
```

### 2. Rodar o ecr-push.sh

```bash
cd aula-09/
chmod +x ecr-push.sh
./ecr-push.sh
```

O script irá:
1. Detectar o Account ID automaticamente
2. Criar o repositório `technova-api` no ECR (idempotente)
3. Aplicar lifecycle policy (expira imagens untagged em 1 dia, mantém 10 tagged)
4. Autenticar o Docker no ECR
5. Buildar a imagem (multi-stage)
6. Fazer push com as tags: `sha-<commit>`, `latest` e, se houver git tag `v*.*.*`, as tags semver

### 3. Fazer pull por tag (rollback)

```bash
# Substitua pelo seu Account ID e SHA real
docker pull <ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com/technova-api:sha-a3f91c2
docker pull <ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com/technova-api:latest
docker pull <ACCOUNT_ID>.dkr.ecr.us-east-1.amazonaws.com/technova-api:1.0.0
```

### 4. Rodar a API localmente

```bash
npm install
npm start
curl http://localhost:3000/health
curl http://localhost:3000/api/orders
```

---

## Workflow de AI Review

Dispara automaticamente em Pull Requests que modificam `aula-09/**`.

### Como funciona

1. Coleta o diff do PR (apenas linhas adicionadas `+`)
2. Executa `.github/scripts/ai-review.js` com 13 regras de análise
3. Posta (ou atualiza) um comentário no PR com tabela de achados
4. Aplica o quality gate:
   - Achados **CRITICAL** → workflow falha → PR bloqueado
   - Achados **WARNING / INFO** → workflow passa → PR pode ser mergeado

### Regras CRITICAL

| ID | Descrição |
|----|-----------|
| `hardcoded-secret` | Credenciais hardcoded (password=, apikey=, token=…) |
| `eval-usage` | Uso de `eval()` — risco de RCE |
| `sql-injection` | Concatenação de variáveis em queries SQL |
| `command-injection` | Input do usuário em `exec`/`spawn` |
| `insecure-deserialization` | `JSON.parse()` direto em `req.body` |

### Testar o AI Review localmente

```bash
# Gerar um diff de teste
git diff main HEAD -- '*.js' > /tmp/test.diff

# Rodar o script manualmente
node .github/scripts/ai-review.js --diff /tmp/test.diff --output /tmp/result.json

# Ver resultado
cat /tmp/result.json | jq .
```

---

## Workflow CI (opcional — Parte 7)

O `ci.yml` executa:
1. **Job `test`**: lint (ESLint) + testes unitários (Jest) → em todos os pushes
2. **Job `ecr-push`**: build + push para ECR → apenas na branch `main`, após o `test` passar

### Configurar Secrets no GitHub

No repositório, vá em **Settings > Secrets and variables > Actions** e adicione:

| Secret | Valor |
|--------|-------|
| `AWS_ACCESS_KEY_ID` | Da sessão do Learner Lab |
| `AWS_SECRET_ACCESS_KEY` | Da sessão do Learner Lab |
| `AWS_SESSION_TOKEN` | Da sessão do Learner Lab |

> As credenciais do Learner Lab expiram a cada ~4 horas. Atualize os Secrets sempre que reabrir o Lab.

---

## Screenshots (evidências)

| Arquivo | Descrição |
|---------|-----------|
| `screenshots/ecr-console.png` | Console ECR com as tags sha, latest e semver |
| `screenshots/ai-review-comment.png` | Comentário do AI review em um PR |
| `screenshots/ecr-push-ok.png` | Execução do ecr-push.sh concluída |
| `screenshots/quality-gate-block.png` | PR bloqueado por achado CRITICAL |

---

## Aprendizados

- **Amazon ECR** integra nativamente com IAM e os demais serviços AWS, sendo a escolha natural para infraestrutura AWS — sem necessidade de credenciais extras além das já usadas no Learner Lab.
- **Estratégia de tagging com três camadas** (sha/latest/semver) garante rastreabilidade, conveniência e compatibilidade semântica para sistemas downstream.
- **AI Review com análise estática local** é eficaz para detectar padrões conhecidos (OWASP Top 10) sem depender de LLMs externos — ideal para ambientes com restrições de custo/rede.
- **Quality gate no CI** força que problemas críticos sejam resolvidos antes do merge, movendo a segurança para a esquerda no ciclo de desenvolvimento (shift-left security).
- **Lifecycle policy no ECR** evita acúmulo de imagens e reduz custos de armazenamento automaticamente.
