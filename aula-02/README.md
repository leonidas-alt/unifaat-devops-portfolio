# Aula 02 — Docker Compose com múltiplos serviços

**Aluna:** Emilly Santos de Oliveira | **RA:** 4023575  
**Disciplina:** DevOps — Centro Universitário UniFAAT 2026-2

---

## Objetivo

Orquestrar uma aplicação composta por três serviços com Docker Compose:

| Serviço | Imagem | Função |
|---------|--------|--------|
| `api` | Node.js 20-alpine (build local) | API REST com Express |
| `postgres` | postgres:15-alpine | Banco de dados relacional |
| `redis` | redis:7-alpine | Cache em memória |

---

## Estrutura de arquivos

```
aula-02/
├── docker-compose.yml     # Orquestração dos serviços
├── .env.example           # Template de variáveis (copiar para .env)
└── app/
    ├── Dockerfile         # Multi-stage build, USER node
    ├── server.js          # API Express + pg + ioredis
    ├── package.json       # Dependências fixadas com versão exata
    └── .dockerignore      # Exclui node_modules e .env do build
```

---

## Como executar

```bash
# 1. Clone o repositório e acesse a pasta
cd aula-02

# 2. Crie o arquivo .env a partir do exemplo
cp .env.example .env
# Edite .env e preencha POSTGRES_PASSWORD com uma senha segura

# 3. Suba os serviços
docker compose up -d

# 4. Verifique o status (aguarde todos ficarem "healthy")
docker compose ps

# 5. Teste os endpoints
curl http://localhost:3000/        # informações da API
curl http://localhost:3000/health  # healthcheck
curl http://localhost:3000/db      # conectividade com PostgreSQL
curl http://localhost:3000/cache   # leitura/escrita no Redis

# 6. Visualize logs
docker compose logs -f api

# 7. Encerrar (mantém o volume do PostgreSQL)
docker compose down

# 7b. Encerrar removendo também os dados persistidos
docker compose down -v
```

---

## Conceitos aplicados

### Healthchecks
Cada serviço define um `healthcheck` próprio:
- **postgres** → `pg_isready` verifica se o banco aceita conexões
- **redis** → `redis-cli ping` confirma que o servidor responde
- **api** → `wget` na rota `/health` garante que a aplicação Express iniciou

### `depends_on` com `condition: service_healthy`
A API só sobe **depois** que PostgreSQL e Redis passam nos healthchecks, evitando erros de conexão durante a inicialização.

### Rede bridge customizada (`devops-network`)
Containers se comunicam pelo nome do serviço (ex.: `postgres`, `redis`) sem expor portas internas para o host.

### Volume nomeado (`devops_postgres_data`)
Dados do PostgreSQL sobrevivem a `docker compose down`. Apenas `docker compose down -v` os remove.

### Variáveis de ambiente via `.env`
Credenciais e configurações ficam fora do `docker-compose.yml`, seguindo o princípio *12-factor app* de separar configuração de código.

### Dockerfile multi-stage + `USER node`
- **Stage `deps`**: instala só dependências de produção com `npm ci --omit=dev`
- **Stage `final`**: copia apenas o necessário, reduzindo a superfície de ataque
- Execução como `USER node` (não-root) por boas práticas de segurança
