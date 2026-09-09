# Portfólio DevOps — UniFAAT 2026-2

**Aluno:** Emilly Santos de Oliveira 
**RA:** 4023575
**Disciplina:** DevOps — Centro Universitário UniFAAT  
**Professor:** Alexandre Tavares  
**Semestre:** 2026-2

## Sobre

Repositório de atividades e projetos da disciplina de DevOps.
Aqui documento minha evolução desde os fundamentos de Git e Docker até pipelines completas de CI/CD.

## Estrutura

- `aula-01/` — Fundamentos de Git e Docker
- `aula-02/` — Docker Compose com Node.js, PostgreSQL e Redis
- `aula-03/` — Terraform + IAM (Groups, Users, Policies, Service Role)

## Aprendizados

### Aula 01 — Fundamentos de Git e Docker
- **Versionamento com Git:** Criação e navegação de branches com `feature branch workflow`, resolução e mesclagem de código via `git merge`.
- **Boas Práticas de Commit:** Uso da convenção *Conventional Commits* (`feat:`, `docs:`, `fix:`) para padronização do histórico.
- **Containerização com Docker:** Criação de imagens customizadas Node.js Alpine via `Dockerfile` multi-camadas e uso de `.dockerignore` para otimização do build.
- **Gerenciamento de Containers:** Execução em segundo plano (`detached mode`), mapeamento de portas locais e inspeção de logs e status da API.

### Aula 02 — Docker Compose com múltiplos serviços
- **Orquestração com Docker Compose:** Definição de múltiplos serviços (API, banco de dados, cache) em um único arquivo `docker-compose.yml`, com comunicação via rede bridge customizada.
- **Variáveis de Ambiente:** Uso de arquivo `.env` com interpolação de variáveis no Compose para separar configuração de código (`12-factor app`).
- **Healthchecks e Dependências:** Configuração de `healthcheck` em cada serviço e uso de `depends_on` com `condition: service_healthy` para garantir ordem de inicialização segura.
- **Persistência de Dados:** Volume nomeado no PostgreSQL para sobreviver a `docker compose down`, com Redis intencional­mente efêmero por ser apenas cache.
- **Segurança em Containers:** Dockerfile multi-stage para reduzir superfície de ataque, execução como `USER node` (não-root) e `npm ci --omit=dev` para instalar apenas dependências de produção.

### Aula 03 — Terraform + IAM
- **Infraestrutura como Código:** Definição completa de recursos IAM (groups, users, policies, roles) em arquivos `.tf` versionados, substituindo cliques manuais no Console por código auditável e reproduzível.
- **RBAC com menor privilégio:** Criação de dois grupos com responsabilidades distintas (`developers` e `platform-eng`) e distribuição de três usuários com permissões granulares — actions específicas em resources limitados por prefixo `technova-*`.
- **Policies com Condition e Deny explícito:** A política `ec2-s3-full` restringe Start/Stop de instâncias EC2 apenas àquelas com tag `Project = TechNova` via `Condition`. A política `deny-destructive` usa `Effect: Deny` para bloquear ações de exclusão independentemente de qualquer Allow.
- **Service Role para EC2:** Criação de uma IAM Role com trust policy para `ec2.amazonaws.com`, política de leitura/escrita restrita ao bucket `technova-app-data-*` e Instance Profile para associação à instância.
- **Terraform Workflow:** Uso de `terraform init`, `validate`, `fmt`, `plan` e `apply` com `-var-file`, garantindo que o código é verificado antes de ser aplicado.
