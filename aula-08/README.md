# Aula 08 — Pipeline CI com GitHub Actions

[![CI — Aula 08](https://github.com/leonidas-alt/unifaat-devops-portfolio/actions/workflows/ci-aula08.yml/badge.svg)](https://github.com/leonidas-alt/unifaat-devops-portfolio/actions/workflows/ci-aula08.yml)

**Aluno:** Emilly Santos de Oliveira  
**RA:** 4023575  
**Disciplina:** DevOps — UniFAAT 2026-2  
**Professor:** Alexandre Tavares

---

## Estrutura de Arquivos

```
aula-08/
├── src/
│   ├── app.js          # API Express (endpoints /, /health, /version)
│   └── server.js       # Entry point — inicia o servidor HTTP
├── __tests__/
│   └── app.test.js     # Testes Jest (13 test cases, 4 describes)
├── screenshots/        # Evidências obrigatórias (R7)
├── Dockerfile          # Multi-stage build (builder + production)
├── .dockerignore       # Exclui node_modules, coverage, etc.
├── .eslintrc.json      # Regras ESLint (R2)
├── .gitignore          # node_modules, .env, coverage
└── package.json        # Scripts: start, lint, test
.github/workflows/
└── ci-aula08.yml       # Workflow CI completo (R1, todos os bônus)
```

---

## Requisitos Implementados

### R1 — Workflow CI Multi-Stage

Arquivo: `.github/workflows/ci-aula08.yml`

O workflow possui **3 jobs encadeados** com dependência em cascata:

```
lint → test → build
```

**Triggers configurados:**
- `push` para `main` (filtrando apenas paths de aula-08)
- `pull_request` para `main`

**Cada job:**
| Job | Nome descritivo | O que faz |
|-----|----------------|-----------|
| `lint` | 🔍 Lint — ESLint | Roda `npm run lint` para verificar estilo |
| `test` | 🧪 Testes — Jest | Roda `npm test` com coverage |
| `build` | 🐳 Build — Docker | Constrói a imagem e executa smoke test |

**Encadeamento com `needs`:**
```yaml
test:
  needs: lint   # só roda se lint passar

build:
  needs: test   # só roda se test passar
```

---

### R2 — ESLint Configurado

Arquivo: `aula-08/.eslintrc.json`

Regras configuradas (as 3 obrigatórias + extras):

| Regra | Configuração | Por quê |
|-------|-------------|---------|
| `semi` | `["error", "always"]` | Ponto e vírgula obrigatório |
| `quotes` | `["error", "single"]` | Aspas simples padrão |
| `no-unused-vars` | `"error"` | Evita variáveis declaradas e não usadas |
| `no-var` | `"error"` | Força uso de `const`/`let` |
| `prefer-const` | `"error"` | Prefere `const` quando não há reassignment |
| `eqeqeq` | `["error", "always"]` | Força `===` ao invés de `==` |
| `indent` | `["error", 2]` | Indentação de 2 espaços |

**Script no package.json:**
```json
"lint": "eslint src/ --ext .js"
```

---

### R3 — Testes com Jest

Arquivo: `aula-08/__tests__/app.test.js`

**13 test cases** distribuídos em **4 describes**, cobrindo **3 endpoints**:

| Describe | Endpoint | Test Cases |
|----------|----------|-----------|
| `GET /` | Raiz | 5 testes (status, campos, content-type) |
| `GET /health` | Health check | 4 testes (status, healthy, uptime, memória) |
| `GET /version` | Versão | 3 testes (status, versão, node) |
| `Rota inexistente` | 404 | 1 teste |

**Script com coverage:**
```json
"test": "jest --coverage --forceExit"
```

**Threshold configurado:** 80% de cobertura de linhas.

---

### R4 — Docker Build no CI

Arquivo: `aula-08/Dockerfile`

O Dockerfile usa **multi-stage build**:

1. **Estágio `builder`** — instala todas as dependências (incluindo devDeps)
2. **Estágio `production`** — copia apenas o necessário, roda como `USER node` (não-root), instala somente dependências de produção (`npm ci --omit=dev`)

**No workflow, a imagem é taggeada com o SHA do commit:**
```yaml
docker build \
  --tag technova-aula08:${{ github.sha }} \
  --tag technova-aula08:latest \
  .
```

**Health check embutido na imagem:**
```dockerfile
HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
  CMD wget -qO- http://localhost:3000/health || exit 1
```

---

### R5 — Secrets Referenciados

Dois secrets configurados no repositório:

| Secret | Uso |
|--------|-----|
| `APP_ENV` | Define o ambiente da aplicação (ex: `production`) |
| `AWS_REGION` | Região AWS para integrações futuras |

**Como configurar no GitHub:**
1. Acesse **Settings → Secrets and variables → Actions**
2. Clique em **New repository secret**
3. Adicione `APP_ENV` com valor `production`
4. Adicione `AWS_REGION` com valor `us-east-1`

**No workflow, os secrets são referenciados assim:**
```yaml
env:
  APP_ENV: ${{ secrets.APP_ENV }}
  AWS_REGION: ${{ secrets.AWS_REGION }}
```

O GitHub **mascara automaticamente** o valor nos logs — você verá `***` onde o valor estaria.

---

### R6 — Status Badge

Badge no `README.md` da raiz do repositório:

```markdown
[![CI — Aula 08](https://github.com/leonidas-alt/unifaat-devops-portfolio/actions/workflows/ci-aula08.yml/badge.svg)](https://github.com/leonidas-alt/unifaat-devops-portfolio/actions/workflows/ci-aula08.yml)
```

O badge exibe automaticamente o status da última execução:
- 🟢 **passing** — todos os jobs passaram
- 🔴 **failing** — algum job falhou

---

### R7 — Screenshots

As evidências devem ser colocadas na pasta `aula-08/screenshots/`:

| Arquivo esperado | O que mostrar |
|-----------------|---------------|
| `screenshot-pipeline-passing.png` | Aba Actions com todos os 3 jobs verdes |
| `screenshot-pipeline-failing.png` | Pipeline com erro intencional (ex: erro de lint) |
| `screenshot-secrets-configured.png` | Settings → Secrets com `APP_ENV` e `AWS_REGION` visíveis (valores ocultos) |

**Como gerar o screenshot de falha intencional:**
1. Introduza um erro de lint temporário no código (ex: usar `var` ao invés de `const`)
2. Faça push — o job `lint` vai falhar
3. Tire o screenshot
4. Reverta o erro

---

## Bônus Implementados

### B1 — Matrix Strategy (+1 ponto)

O job `test` usa matriz para rodar em **Node 18 e Node 20** simultaneamente:

```yaml
strategy:
  matrix:
    node-version: ["18", "20"]
```

Isso garante que a aplicação é compatível com as duas versões LTS do Node.

---

### B2 — Cache de Dependências (+1 ponto)

Todos os jobs usam o cache nativo do `actions/setup-node`:

```yaml
- uses: actions/setup-node@v4
  with:
    node-version: "20"
    cache: "npm"
    cache-dependency-path: aula-08/package-lock.json
```

O cache é keyed pelo hash do `package-lock.json`. Na segunda execução sem mudança de dependências, o passo mostrará **"Cache hit"** nos logs e o `npm ci` será muito mais rápido.

---

### B3 — PR Comment (+1 ponto)

Quando o workflow é disparado por um Pull Request, o job `test` (Node 20) usa `actions/github-script` para criar ou atualizar um comentário automático no PR:

```
✅ CI Aula 08 — Resultado dos Testes
| Etapa             | Status              |
| 🔍 ESLint         | ✅ Passou           |
| 🧪 Jest (Node 20) | ✅ Todos passaram   |
```

O comentário é **atualizado** (não duplicado) em execuções subsequentes do mesmo PR.

---

### B4 — Concurrency Control (+0.5 ponto)

Evita desperdício de minutos do Actions cancelando runs antigas da mesma branch:

```yaml
concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true
```

Exemplo: se você fizer 3 pushes rápidos para a mesma branch, apenas o último vai rodar por completo — os outros dois são cancelados automaticamente.

---

### B5 — Smoke Test no Docker (+0.5 ponto)

Após o `docker build`, o job `build` inicia o container e verifica o endpoint `/health`:

```bash
# Inicia o container
docker run --detach --name smoke-test --publish 3000:3000 technova-aula08:SHA

# Aguarda inicialização
sleep 5

# Testa o health check
STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3000/health)
[ "$STATUS" -eq 200 ] || exit 1

# Remove o container ao final (sempre, mesmo em falha)
docker stop smoke-test && docker rm smoke-test
```

O passo de remoção usa `if: always()` — garante que o container seja removido mesmo se o teste falhar.

---

## Como Rodar Localmente

```bash
# 1. Entrar na pasta
cd aula-08

# 2. Instalar dependências
npm ci

# 3. Rodar o lint
npm run lint

# 4. Rodar os testes
npm test

# 5. Build Docker
docker build -t technova-aula08:local .

# 6. Testar o container
docker run -p 3000:3000 technova-aula08:local

# Em outro terminal:
curl http://localhost:3000/health
```

---

## Conceitos Aprendidos

- **Pipeline CI como código:** O arquivo YAML é a única fonte da verdade para o pipeline — qualquer mudança é rastreável via `git log`.
- **Fail-fast:** A dependência `lint → test → build` garante que erros óbvios (como sintaxe) são detectados antes de gastar tempo com testes e Docker.
- **Matrix testing:** Rodar a mesma suite de testes em múltiplas versões do Node detecta regressões de compatibilidade antes que cheguem à produção.
- **Secrets mascarados:** O GitHub nunca imprime o valor real de um secret nos logs — mesmo que o código tente fazer `echo $SECRET`, o output será `***`.
- **Smoke test:** Uma forma rápida de verificar que a imagem Docker realmente funciona, sem precisar de testes de integração completos.
- **Concurrency:** Evita que múltiplos push rápidos desperdicem os minutos gratuitos do GitHub Actions.
