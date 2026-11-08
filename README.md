# Portfólio DevOps — UniFAAT 2026-2

[![CI — Aula 08](https://github.com/leonidas-alt/unifaat-devops-portfolio/actions/workflows/ci-aula08.yml/badge.svg)](https://github.com/leonidas-alt/unifaat-devops-portfolio/actions/workflows/ci-aula08.yml)
[![CI — Aula 09](https://github.com/leonidas-alt/unifaat-devops-portfolio/actions/workflows/ci-aula09.yml/badge.svg)](https://github.com/leonidas-alt/unifaat-devops-portfolio/actions/workflows/ci-aula09.yml)

**Aluno:** Emilly Santos de Oliveira  
**RA:** 4023575  
**Disciplina:** DevOps — Centro Universitário UniFAAT  
**Professor:** Alexandre Tavares  
**Semestre:** 2026-2

---

## Sobre

Repositório de atividades e projetos da disciplina de DevOps.
Documenta a evolução desde os fundamentos de Git e Docker até pipelines completas de CI/CD com deploy automatizado na AWS.

---

## Estrutura

| Pasta | Conteúdo |
|-------|----------|
| `aula-01/` | Fundamentos de Git e Docker |
| `aula-02/` | Docker Compose com Node.js, PostgreSQL e Redis |
| `aula-03/` | Terraform + IAM (Groups, Users, Policies, Service Role) |
| `aula-04/` | Terraform VPC + EC2 Multi-AZ |
| `aula-05/` | Terraform RDS + Remote State (S3 + DynamoDB) |
| `aula-06/` | Módulos Terraform reutilizáveis (multi-ambiente) |
| `aula-08/` | Pipeline CI com GitHub Actions, ESLint e Jest |
| `aula-09/` | Docker Registry (Amazon ECR) + AI Review no CI/CD |
| `aula-10/` | Terraform GitOps (Plan on PR + Apply on Merge) + CD Pipeline completo |

---

## Aprendizados

### Aula 01 — Fundamentos de Git e Docker

- **Feature branch workflow:** criação e navegação entre branches isoladas antes de realizar merge, evitando conflitos na branch principal.
- **Conventional Commits:** padronização do histórico com prefixos `feat:`, `fix:`, `docs:` para rastreabilidade e geração de changelogs.
- **Docker com Node.js Alpine:** criação de imagens leves via `Dockerfile` multi-camadas e uso de `.dockerignore` para otimizar o contexto de build.
- **Ciclo de vida de containers:** execução em modo detached (`-d`), mapeamento de portas, inspeção de logs e listagem de containers ativos.

### Aula 02 — Docker Compose com múltiplos serviços

- **Orquestração com Docker Compose:** definição de três serviços (`api`, `postgres`, `redis`) em um único `docker-compose.yml` com comunicação via rede bridge customizada (`devops-network`).
- **Variáveis de ambiente com `.env`:** separação de credenciais e configurações do código, seguindo o princípio *12-factor app*.
- **Healthchecks e `depends_on`:** cada serviço define seu próprio `healthcheck` e a API só sobe após PostgreSQL e Redis passarem — evita erros de conexão na inicialização.
- **Persistência de dados:** volume nomeado (`devops_postgres_data`) garante que os dados do PostgreSQL sobrevivem a `docker compose down`; Redis é intencionalmente efêmero por ser apenas cache.
- **Segurança em containers:** Dockerfile multi-stage com `npm ci --omit=dev` e execução como `USER node` (não-root) para reduzir a superfície de ataque.

### Aula 03 — Terraform + IAM

- **Infraestrutura como código:** recursos IAM (groups, users, policies, roles) definidos em arquivos `.tf` versionados — auditáveis, reproduzíveis e revisáveis via Pull Request.
- **RBAC com menor privilégio:** dois grupos com responsabilidades distintas (`developers` e `platform-eng`), com três usuários distribuídos por permissões granulares em recursos com prefixo `technova-*`.
- **Policies com `Condition` e `Deny` explícito:** `ec2-s3-full` restringe Start/Stop de instâncias apenas àquelas com tag `Project = TechNova`; `deny-destructive` bloqueia ações de exclusão independentemente de qualquer Allow.
- **Service Role para EC2:** IAM Role com trust policy para `ec2.amazonaws.com`, política de leitura/escrita restrita ao bucket `technova-app-data-*` e Instance Profile para associação à instância.
- **Terraform workflow:** `init` → `validate` → `fmt` → `plan -var-file` → `apply` → `destroy`, garantindo verificação antes da aplicação.

### Aula 04 — Terraform VPC + EC2 Multi-AZ

- **VPC do zero:** criação de VPC (`10.0.0.0/16`), Internet Gateway, Route Table pública e duas subnets públicas em AZs diferentes (`us-east-1a` e `us-east-1b`).
- **EC2 com Terraform:** provisionamento de instância `t2.micro` com Amazon Linux 2023, Security Group configurado para SSH (porta 22) e API (porta 3000), e Key Pair gerenciado como recurso.
- **Multi-AZ como base de alta disponibilidade:** estrutura de rede preparada para receber um segundo nó em `us-east-1b`, antecipando load balancer e Auto Scaling Group em aulas futuras.
- **Outputs úteis:** IP público, DNS, comando SSH e ID da instância exportados via `outputs.tf` para reutilização em outros módulos.
- **Evidências automatizadas:** script `capturar-evidencias.sh` que registra o estado da infraestrutura via AWS CLI para documentação.

### Aula 05 — Terraform RDS + Remote State

- **RDS PostgreSQL gerenciado:** instância `db.t3.micro` com PostgreSQL 15 em subnets privadas, DB Subnet Group em duas AZs e Security Group restrito ao SG da EC2 (sem exposição pública).
- **Remote state com S3 + DynamoDB:** estado do Terraform armazenado em S3 com criptografia e versionamento; DynamoDB para state locking — evita apply simultâneo em equipe.
- **Separação de responsabilidades:** arquivos `.tf` divididos por camada (`networking.tf`, `ec2.tf`, `rds.tf`, `security_groups.tf`) facilitando leitura e manutenção.
- **Validações em variáveis:** `validation` blocks no `variables.tf` garantem nomes de banco e senhas dentro das regras da AWS antes do plan.
- **Backend separado:** pasta `backend/` com Terraform próprio para criar o bucket S3 e a tabela DynamoDB — infraestrutura que suporta a infraestrutura.

### Aula 06 — Módulos Terraform Reutilizáveis

- **Biblioteca de módulos:** quatro módulos independentes (`vpc`, `ec2`, `rds`, `security-group`) na pasta `modules/`, cada um com `variables.tf`, `main.tf` e `outputs.tf` próprios.
- **Composição de módulos:** output de um módulo alimenta o input de outro (ex.: `vpc_id` do módulo VPC é passado para os módulos EC2 e Security Group); Terraform resolve o grafo de dependências automaticamente.
- **Multi-ambiente com mesma base:** ambientes `dev` e `staging` provisionados a partir dos mesmos módulos, apenas com `terraform.tfvars` diferentes — VPC CIDRs, nomes e tamanhos de instância distintos por ambiente.
- **Reutilização sem duplicação:** uma mudança no módulo `vpc` se propaga para todos os ambientes que o utilizam, eliminando copy-paste de código Terraform.

### Aula 08 — Pipeline CI com GitHub Actions

- **Workflow multi-job encadeado:** três jobs com dependência em cascata (`lint` → `test` → `docker-build`), onde cada job só executa se o anterior passar.
- **ESLint no CI:** análise estática de código em todo push e pull request; o pipeline falha em erros de lint antes mesmo de rodar os testes.
- **Jest com cobertura:** relatório de cobertura gerado via `--coverage` e publicado como artefato no Actions para consulta sem reexecutar o pipeline.
- **Docker build no CI:** validação do `Dockerfile` multi-stage como última etapa — garante que a imagem que vai para produção compila e passa em todas as verificações.
- **Status badge:** badge de CI no README reflete em tempo real o estado do pipeline da branch `main`.

### Aula 09 — Docker Registry (Amazon ECR) + AI Review

- **Push automatizado para Amazon ECR:** pipeline que autentica com credenciais temporárias do Learner Lab, faz login no ECR, cria o repositório se não existir e faz push com tags `sha-XXXXXXX` e `latest`.
- **Tags semânticas:** lógica de tagging que gera `sha-SHORT`, `latest` e, se existir git tag no commit, também `MAJOR.MINOR.PATCH`, `MAJOR.MINOR` e `MAJOR` — facilitando rollback por versão.
- **AI Review em PRs:** workflow `ai-review.yml` que analisa estaticamente cada Pull Request com 13 regras de segurança e qualidade (hardcoded secrets, `console.log` em produção, dependências sem versão fixada, etc.) e posta o resultado como comentário no PR.
- **Script de push local (`ecr-push.sh`):** alternativa ao workflow para push manual quando as credenciais do Lab expiram durante a sessão — útil como fallback.
- **Lifecycle policy no ECR:** política que mantém apenas as 10 imagens mais recentes, evitando acúmulo e custos desnecessários de armazenamento.

### Aula 10 — Terraform GitOps + CD Pipeline Completo

- **GitOps com Terraform:** plan automático em PRs (comentário formatado no PR, atualizado sem duplicata a cada push) e apply automático no merge para `main` — o repositório é sempre a única fonte da verdade da infraestrutura.
- **Autenticação Learner Lab vs produção:** credenciais de sessão (`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_SESSION_TOKEN`) como Secrets no Lab; documentação do padrão ideal em produção via OIDC + IAM Role (sem chaves estáticas — o Lab não permite criar OIDC Provider).
- **CD Pipeline em 4 jobs:** `lint` (ESLint) → `test` (Jest com cobertura) → `build-push` (Docker multi-stage + push ECR com tags SHA e `latest`) → `deploy` (SSH na EC2).
- **Estratégia Recreate:** deploy via SSH com `docker stop → rm → pull → run`, incluindo login no ECR antes do pull. Prós: simplicidade, estado limpo. Contras: downtime durante o deploy.
- **Health check automatizado:** pipeline só considera o deploy bem-sucedido após confirmar que `/health` retorna HTTP 200, com 10 retries de 10 segundos cada — falha explicitamente se a API não responder.
- **Infraestrutura como código:** VPC, Subnet pública, Internet Gateway, Security Group, EC2 com Docker instalado via `user_data` e repositório ECR, tudo gerenciado por Terraform com backend remoto no S3.
- **Runbook de rollback:** procedimento documentado em `docs/runbook-rollback.md` cobrindo login no ECR, pull da imagem anterior, recreate e verificação de health check.
