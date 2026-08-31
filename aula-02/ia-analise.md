# Análise do Uso de IA — Aula 02 TF

## Prompt Utilizado
"Crie um docker-compose.yml para uma aplicação Node.js 20 com Express que usa PostgreSQL 15 como banco de dados e Redis 7 como cache. A API roda na porta 3000. O PostgreSQL precisa de volume nomeado para persistência. Todos os serviços devem estar na mesma rede bridge customizada. Use variáveis de ambiente com interpolação de arquivo .env Adicione healthchecks, depends_on com condition, e restart policy unless-stopped.

## Output Original do Kiro

# ============================================================
# docker-compose.yml — aula-02
# Aluna : Emilly Santos de Oliveira | RA: 4023575
# Disciplina: DevOps — UniFAAT 2026-2
#
# Serviços:
#   api      — Node.js 20 / Express (porta 3000)
#   postgres — PostgreSQL 15 com volume nomeado
#   redis    — Redis 7 (cache em memória)
#
# Uso:
#   cp .env.example .env   # preencha as senhas
#   docker compose up -d   # sobe todos os serviços
#   docker compose down -v # destrói containers + volumes
# ============================================================

services:

  # ----------------------------------------------------------
  # API Node.js 20
  # Depende de postgres e redis estarem saudáveis antes
  # de subir, para evitar erros de conexão na inicialização.
  # ----------------------------------------------------------
  api:
    build:
      context: ./app
      dockerfile: Dockerfile
    container_name: devops-api
    restart: unless-stopped
    ports:
      - "${PORT:-3000}:3000"
    environment:
      NODE_ENV: ${NODE_ENV:-development}
      PORT: ${PORT:-3000}
      POSTGRES_HOST: ${POSTGRES_HOST:-postgres}
      POSTGRES_PORT: ${POSTGRES_PORT:-5432}
      POSTGRES_DB: ${POSTGRES_DB}
      POSTGRES_USER: ${POSTGRES_USER}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
      REDIS_HOST: ${REDIS_HOST:-redis}
      REDIS_PORT: ${REDIS_PORT:-6379}
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_healthy
    healthcheck:
      test: ["CMD", "wget", "-qO-", "http://localhost:3000/health"]
      interval: 30s
      timeout: 10s
      retries: 5
      start_period: 20s
    networks:
      - devops-network

  # ----------------------------------------------------------
  # PostgreSQL 15
  # Volume nomeado garante persistência dos dados mesmo
  # após `docker compose down` (apenas `down -v` remove).
  # ----------------------------------------------------------
  postgres:
    image: postgres:15-alpine
    container_name: devops-postgres
    restart: unless-stopped
    environment:
      POSTGRES_DB: ${POSTGRES_DB}
      POSTGRES_USER: ${POSTGRES_USER}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
    volumes:
      - postgres_data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER} -d ${POSTGRES_DB}"]
      interval: 10s
      timeout: 5s
      retries: 5
      start_period: 10s
    networks:
      - devops-network

  # ----------------------------------------------------------
  # Redis 7
  # Cache em memória. Sem volume: dados são efêmeros
  # por design (apenas cache, não estado persistente).
  # ----------------------------------------------------------
  redis:
    image: redis:7-alpine
    container_name: devops-redis
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 5s
      retries: 5
      start_period: 5s
    networks:
      - devops-network

# ----------------------------------------------------------------
# Volumes nomeados
# Gerenciados pelo Docker; sobrevivem a `docker compose down`.
# Use `docker compose down -v` para remover junto com containers.
# ----------------------------------------------------------------
volumes:
  postgres_data:
    name: devops_postgres_data

# ----------------------------------------------------------------
# Rede bridge customizada
# Containers se comunicam pelo nome do serviço (ex.: "postgres")
# sem expor portas desnecessariamente para o host.
# ----------------------------------------------------------------
networks:
  devops-network:
    driver: bridge
    name: devops-network

## 3. Alterações Realizadas Manualmente

| Componente | O que mudei | Justificativa Técnica / Motivo |
|---|---|---|
| **Build Context** | Corrigido `build.context` da API de `./app` para `.` | O `Dockerfile` encontra-se na raiz do diretório do projeto (`aula-02`). Manter `./app` causava falha imediata na etapa de build (`build path not found`). |
| **Variáveis da API** | Mapeamento ajustado para `DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_USER` e `DB_PASSWORD` | O Kiro assumiu padrões genéricos (`POSTGRES_HOST`, `POSTGRES_DB`). O código-fonte da API (`app.js`) lê estritamente as variáveis prefixadas por `DB_`, o que causaria erro de conexão com a base de dados em tempo de execução. |
| **Ambiente do Postgres** | Mantidas as chaves oficiais `POSTGRES_DB`, `POSTGRES_USER` e `POSTGRES_PASSWORD` | A imagem oficial `postgres:15-alpine` exige exatamente essa nomenclatura para inicializar a base e o superusuário corretamente no bootstrap do container. |
| **Healthchecks** | Mantidas e refinadas as rotinas para `postgres` (`pg_isready`) e `redis` (`redis-cli ping`) | Atendem estritamente ao requisito do trabalho e garantem que o orquestrador valide a integridade física dos serviços de banco/cache antes de liberar o container da aplicação. |
| **Orquestração** | Mantida a diretiva `depends_on` com `condition: service_healthy` | Impede *race conditions* no momento da subida do ambiente, garantindo que o pool de conexões do Node.js não tente conectar enquanto os drivers do banco ainda estão subindo. |
| **Persistência** | Mantido o volume nomeado `postgres_data` apontando para `/var/lib/postgresql/data` | Garante a persistência do estado e integridade dos dados mesmo com o encerramento (`docker compose down`) dos containers. |
| **Rede Isolada** | Mantida a rede customizada `devops-network` (driver `bridge`) | Permite a resolução interna de nomes via DNS do Docker entre os containers, isolando o tráfego de banco e cache da rede pública do host. |
| **Resiliência** | Mantida a política `restart: unless-stopped` em todos os serviços | Assegura que falhas temporárias de execução reiniciem automaticamente os serviços sem intervenção manual, respeitando a parada explícita informada pelo usuário. |

## 4. O que o Kiro Acertou

- **Arquitetura Multi-Container:** Declarou corretamente os três serviços exigidos (`api`, `postgres` e `redis`) com imagens adequadas e leves (`postgres:15-alpine` e `redis:7-alpine`).
- **Segurança de Dados Sensíveis:** Utilizou interpolação de variáveis de ambiente via arquivo `.env`, evitando o vazamento de senhas hardcoded dentro do manifesto YAML.
- **Persistência e Isolamento:** Configurou corretamente o volume nomeado para o PostgreSQL e criou uma rede bridge customizada dedicada para comunicação interna por DNS de container.
- **Orquestração Inteligente:** Aplicou corretamente o uso de `depends_on` acoplado ao status `service_healthy`.
- **Integridade dos Serviços:** Adicionou testes de healthcheck válidos para PostgreSQL (`pg_isready`) e Redis (`redis-cli ping`).
- **Boas Práticas de Documentação:** Inseriu comentários explicativos ao longo do arquivo e cabeçalho identificador, facilitando a leitura e manutenção da infraestrutura.

---

## 5. O que o Kiro Errou ou Omitiu

- **Contexto de Build Incorreto:** Apontou o contexto para um subdiretório inexistente (`./app`), quebrando a execução do comando `docker compose build`.
- **Incompatibilidade com o Código-Fonte:** Gerou um contrato de variáveis de ambiente na API (`POSTGRES_HOST`, `POSTGRES_DB`) divergente do que a aplicação (`app.js`) realmente consumia (`DB_HOST`, `DB_NAME`), o que resultaria em falhas silenciosas ou erros de conexão ao subir a API.
- **Healthcheck Desnecessário / Quebrado na API:** Adicionou uma verificação via `wget` na rota `/health` da API sem checar previamente se essa rota existia na aplicação.
- **Premissa de Execução Cega:** Embora o YAML gerado fosse sintaticamente bonito, ele não funcionaria de primeira sem a intervenção humana para alinhar o manifesto com os arquivos do projeto real.

## Minha Avaliação

* **Tempo economizado usando IA:** aproximadamente 30 minutos.
* **Tempo gasto validando/corrigindo:** aproximadamente 20 minutos.
* **Nota para o output da IA (1-10):** 8/10.
* **Usaria novamente para este tipo de tarefa?** Sim. O Kiro foi útil para criar uma estrutura inicial rapidamente e sugerir configurações importantes do Docker Compose. Porém, eu não utilizaria o código gerado diretamente sem antes comparar com a estrutura do projeto.
