# Aula 06 — Biblioteca de Módulos Terraform (TechNova)

## Visão Geral

Nesta aula construímos uma biblioteca de módulos Terraform reutilizáveis para provisionar a infraestrutura completa da TechNova na AWS. O princípio central é a **composição de módulos**: o output de um módulo alimenta o input de outro, e o Terraform resolve o grafo de dependências automaticamente.

Com a mesma biblioteca de módulos (`modules/`), provisionamos dois ambientes independentes apenas trocando variáveis:

| Aspecto | Dev | Staging |
|---|---|---|
| VPC CIDR | `10.0.0.0/16` | `10.1.0.0/16` |
| Subnets Públicas | `10.0.1.0/24`, `10.0.2.0/24` | `10.1.1.0/24`, `10.1.2.0/24` |
| Subnets Privadas | `10.0.3.0/24`, `10.0.4.0/24` | `10.1.3.0/24`, `10.1.4.0/24` |
| EC2 | t2.micro | t2.micro |
| RDS | db.t3.micro | db.t3.micro |
| DB Name | `technova_dev` | `technova_staging` |
| Naming | `technova-dev-*` | `technova-staging-*` |

---

## Diagrama da Infraestrutura

```
┌─────────────────────────────────────────────────────────────────────────┐
│  AWS — us-east-1                                                        │
│                                                                         │
│  ┌──────────────────────────────────────────────────────────────────┐   │
│  │  VPC  10.0.0.0/16  (dev)  /  10.1.0.0/16  (staging)            │   │
│  │                                                                  │   │
│  │  ┌─────────────────────────┐  ┌──────────────────────────────┐  │   │
│  │  │  Subnet Pública         │  │  Subnet Pública              │  │   │
│  │  │  us-east-1a             │  │  us-east-1b                  │  │   │
│  │  │  10.0.1.0/24            │  │  10.0.2.0/24                 │  │   │
│  │  │                         │  │                              │  │   │
│  │  │  ┌───────────────────┐  │  │                              │  │   │
│  │  │  │  EC2 (api_server) │  │  │                              │  │   │
│  │  │  │  t2.micro         │  │  │                              │  │   │
│  │  │  │  SG: api_sg       │  │  │                              │  │   │
│  │  │  │  porta 80 (HTTP)  │  │  │                              │  │   │
│  │  │  │  porta 22 (SSH)   │  │  │                              │  │   │
│  │  │  └───────────────────┘  │  │                              │  │   │
│  │  └─────────────────────────┘  └──────────────────────────────┘  │   │
│  │                 │                                                │   │
│  │           Internet Gateway ←── Route Table Pública              │   │
│  │                 │                                                │   │
│  │  ┌─────────────────────────┐  ┌──────────────────────────────┐  │   │
│  │  │  Subnet Privada         │  │  Subnet Privada              │  │   │
│  │  │  us-east-1a             │  │  us-east-1b                  │  │   │
│  │  │  10.0.3.0/24            │  │  10.0.4.0/24                 │  │   │
│  │  │                         │  │                              │  │   │
│  │  │  ┌───────────────────┐  │  │                              │  │   │
│  │  │  │  RDS PostgreSQL   │  │  │  (DB Subnet Group            │  │   │
│  │  │  │  db.t3.micro      │  │  │   abrange as duas)           │  │   │
│  │  │  │  SG: rds_sg       │  │  │                              │  │   │
│  │  │  │  porta 5432       │  │  │                              │  │   │
│  │  │  │  (apenas da VPC)  │  │  │                              │  │   │
│  │  │  └───────────────────┘  │  │                              │  │   │
│  │  └─────────────────────────┘  └──────────────────────────────┘  │   │
│  └──────────────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## Diagrama de Composição dos Módulos Terraform

```
environments/dev/main.tf  (ou staging/main.tf)
│
├── module "vpc"
│   ├── input:  vpc_cidr, project_name, environment, subnets
│   └── output: vpc_id ──────────────────┬─────────────┐
│               public_subnet_ids[0] ────│─────────┐   │
│               private_subnet_ids ──────│────┐    │   │
│                                        │    │    │   │
├── module "api_sg"                      │    │    │   │
│   ├── input:  vpc_id ◄─────────────────┘    │    │   │
│   └── output: sg_id ───────────────────┐    │    │   │
│                                        │    │    │   │
├── module "rds_sg"                      │    │    │   │
│   ├── input:  vpc_id ◄──────────────────────│────┘   │
│   └── output: sg_id ──────────────┐    │    │        │
│                                   │    │    │        │
├── module "api_server" (EC2)        │    │    │        │
│   ├── input:  subnet_id ◄──────────────│────┘        │
│   │           security_group_ids ◄─────┘             │
│   └── output: instance_id, public_ip, private_ip     │
│                                                      │
└── module "database" (RDS)                            │
    ├── input:  subnet_ids ◄────────────────────────────┘
    │           security_group_ids ◄────┘
    └── output: db_endpoint, db_name, db_port
```

---

## Módulos Disponíveis

### `modules/vpc/`

Cria VPC, subnets dinâmicas com `for_each`, Internet Gateway e route table pública.

| Input | Tipo | Descrição |
|---|---|---|
| `vpc_cidr` | `string` | CIDR block da VPC |
| `project_name` | `string` | Nome do projeto |
| `environment` | `string` | Ambiente (dev, staging, prod) |
| `subnets` | `map(object)` | Mapa de subnets com `cidr`, `az`, `type` |

| Output | Descrição |
|---|---|
| `vpc_id` | ID da VPC criada |
| `public_subnet_ids` | Lista de IDs das subnets públicas |
| `private_subnet_ids` | Lista de IDs das subnets privadas |

---

### `modules/security-group/`

Security Group genérico com regras de ingress/egress configuráveis como lista de objetos.

| Input | Tipo | Descrição |
|---|---|---|
| `name` | `string` | Nome do Security Group |
| `vpc_id` | `string` | ID da VPC |
| `ingress_rules` | `list(object)` | Regras de entrada |
| `egress_rules` | `list(object)` | Regras de saída |

| Output | Descrição |
|---|---|
| `sg_id` | ID do Security Group |

---

### `modules/ec2/`

Instância EC2 com AMI, tipo, subnet e Security Groups configuráveis.

| Input | Tipo | Descrição |
|---|---|---|
| `instance_name` | `string` | Nome da instância |
| `ami_id` | `string` | ID da AMI |
| `instance_type` | `string` | Tipo (padrão: `t2.micro`) |
| `subnet_id` | `string` | ID da subnet pública |
| `security_group_ids` | `list(string)` | IDs dos Security Groups |
| `key_name` | `string` | Nome do key pair SSH |

| Output | Descrição |
|---|---|
| `instance_id` | ID da instância |
| `public_ip` | IP público |

---

### `modules/rds/`

DB Subnet Group + instância RDS PostgreSQL 15 nas subnets privadas.

| Input | Tipo | Descrição |
|---|---|---|
| `db_name` | `string` | Nome do banco |
| `db_username` | `string` | Usuário master |
| `db_password` | `string` (sensitive) | Senha master |
| `subnet_ids` | `list(string)` | Subnets privadas |
| `security_group_ids` | `list(string)` | IDs dos Security Groups |
| `instance_class` | `string` | Classe (padrão: `db.t3.micro`) |

| Output | Descrição |
|---|---|
| `db_endpoint` | Endpoint de conexão |
| `db_name` | Nome do banco |
| `db_port` | Porta (5432) |

---

## Estrutura do Projeto

```
aula-06/
├── README.md
├── .gitignore
├── modules/
│   ├── vpc/
│   │   ├── main.tf        # VPC, subnets (for_each), IGW, route table
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── security-group/
│   │   ├── main.tf        # SG + regras dinâmicas via count
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── ec2/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   └── rds/
│       ├── main.tf        # DB Subnet Group + instância RDS PostgreSQL
│       ├── variables.tf
│       └── outputs.tf
└── environments/
    ├── dev/
    │   ├── main.tf        # Composição dos módulos — CIDRs 10.0.x.x
    │   ├── variables.tf
    │   ├── outputs.tf
    │   ├── providers.tf
    │   └── terraform.tfvars
    └── staging/
        ├── main.tf        # Composição dos módulos — CIDRs 10.1.x.x
        ├── variables.tf
        ├── outputs.tf
        ├── providers.tf
        └── terraform.tfvars
```

---

## Como Usar

### Pré-requisitos

- Terraform >= 1.0
- AWS CLI configurado (AWS Academy: `source aws-creds.sh`)
- Key Pair criado no EC2 com o nome definido em `key_name`

### Subir um ambiente

```bash
cd environments/dev      # ou environments/staging

terraform init
terraform validate
terraform plan
terraform apply
```

### Destruir o ambiente

```bash
terraform destroy
```

### Criar um novo ambiente (ex: prod)

1. Copie `environments/dev/` para `environments/prod/`
2. Altere o CIDR no `main.tf` para evitar conflito (ex: `10.2.0.0/16`)
3. Atualize o `terraform.tfvars` com os valores do novo ambiente
4. Execute `terraform init && terraform apply`

---

## Conceitos Aplicados

- **Módulos reutilizáveis** — mesma base de código para todos os ambientes
- **Composição de módulos** — outputs de um módulo viram inputs de outro
- **`for_each` em subnets** — subnets criadas dinamicamente a partir de um mapa
- **`count` em regras de SG** — regras de ingress/egress criadas dinamicamente
- **Sensitive variables** — senha do banco marcada como `sensitive = true`
- **Separação de ambientes** — cada ambiente tem seu próprio state file
