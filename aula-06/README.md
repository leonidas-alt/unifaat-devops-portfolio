# Biblioteca de Módulos Terraform — TechNova

## Visão Geral

Esta biblioteca contém módulos Terraform reutilizáveis para provisionar a infraestrutura da TechNova na AWS. Com ela, qualquer membro da equipe pode criar ambientes completos (VPC, Security Groups, EC2, RDS) a partir dos mesmos módulos, apenas alterando as variáveis.

Os módulos seguem o padrão de **composição**: o output de um módulo alimenta o input de outro, criando um grafo de dependências gerenciado automaticamente pelo Terraform.

---

## Arquitetura

```
environments/dev/main.tf
environments/staging/main.tf
        │
        ├── module "vpc"          → cria VPC, subnets, IGW, route tables
        │       │
        │       └── vpc_id ──────────► module "api_sg"
        │       └── vpc_id ──────────► module "rds_sg"
        │       └── public_subnet_ids[0] ──► module "api_server" (EC2)
        │       └── private_subnet_ids ──► module "database" (RDS)
        │
        ├── module "api_sg"       → Security Group para o servidor API
        │       └── sg_id ───────────► module "api_server" (EC2)
        │
        ├── module "rds_sg"       → Security Group para o banco de dados
        │       └── sg_id ───────────► module "database" (RDS)
        │
        ├── module "api_server"   → Instância EC2 na subnet pública
        │
        └── module "database"    → Instância RDS PostgreSQL nas subnets privadas
```

---

## Módulos Disponíveis

### Módulo VPC (`modules/vpc/`)

**Descrição:** Cria uma VPC completa com subnets dinâmicas usando `for_each`, Internet Gateway e route tables.

**Inputs:**

| Nome | Tipo | Obrigatório | Descrição |
|---|---|---|---|
| `vpc_cidr` | `string` | Sim | CIDR block da VPC |
| `project_name` | `string` | Sim | Nome do projeto para tags |
| `environment` | `string` | Sim | Ambiente (dev, staging, prod) |
| `subnets` | `map(object)` | Sim | Mapa de subnets: cada chave é o nome; valor tem `cidr`, `az`, `type` (public/private) |

**Outputs:**

| Nome | Descrição |
|---|---|
| `vpc_id` | ID da VPC criada |
| `vpc_cidr` | CIDR block da VPC |
| `public_subnet_ids` | Lista de IDs das subnets públicas |
| `private_subnet_ids` | Lista de IDs das subnets privadas |
| `internet_gateway_id` | ID do Internet Gateway |

**Exemplo de uso:**

```hcl
module "vpc" {
  source = "../../modules/vpc"

  vpc_cidr     = "10.0.0.0/16"
  project_name = "technova"
  environment  = "dev"

  subnets = {
    "public-1"  = { cidr = "10.0.1.0/24", az = "us-east-1a", type = "public" }
    "public-2"  = { cidr = "10.0.2.0/24", az = "us-east-1b", type = "public" }
    "private-1" = { cidr = "10.0.3.0/24", az = "us-east-1a", type = "private" }
    "private-2" = { cidr = "10.0.4.0/24", az = "us-east-1b", type = "private" }
  }
}
```

---

### Módulo Security Group (`modules/security-group/`)

**Descrição:** Security Group genérico que aceita regras de ingress como lista de objetos. Pode ser usado para qualquer finalidade (API, RDS, Bastion).

**Inputs:**

| Nome | Tipo | Obrigatório | Descrição |
|---|---|---|---|
| `name` | `string` | Sim | Nome do Security Group |
| `vpc_id` | `string` | Sim | ID da VPC |
| `ingress_rules` | `list(object)` | Não | Regras de entrada (from_port, to_port, protocol, cidr_blocks, description) |
| `egress_rules` | `list(object)` | Não | Regras de saída (padrão: todo tráfego liberado) |
| `description` | `string` | Não | Descrição do SG (padrão: "Managed by Terraform") |
| `environment` | `string` | Sim | Ambiente |
| `project_name` | `string` | Sim | Nome do projeto |

**Outputs:**

| Nome | Descrição |
|---|---|
| `sg_id` | ID do Security Group criado |
| `sg_name` | Nome do Security Group |

**Exemplo de uso:**

```hcl
module "api_sg" {
  source = "../../modules/security-group"

  name         = "technova-dev-api-sg"
  vpc_id       = module.vpc.vpc_id   # ← Composição com módulo VPC
  environment  = "dev"
  project_name = "technova"

  ingress_rules = [
    {
      from_port   = 80
      to_port     = 80
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
      description = "HTTP from anywhere"
    }
  ]
}
```

---

### Módulo EC2 (`modules/ec2/`)

**Descrição:** Cria uma instância EC2 com AMI, tipo, subnet e Security Groups configuráveis.

**Inputs:**

| Nome | Tipo | Obrigatório | Descrição |
|---|---|---|---|
| `instance_name` | `string` | Sim | Nome da instância |
| `ami_id` | `string` | Sim | ID da AMI |
| `subnet_id` | `string` | Sim | ID da subnet |
| `security_group_ids` | `list(string)` | Sim | Lista de IDs dos Security Groups |
| `key_name` | `string` | Sim | Nome do key pair SSH |
| `instance_type` | `string` | Não | Tipo da instância (padrão: `t2.micro`) |
| `user_data` | `string` | Não | Script de user data |
| `environment` | `string` | Sim | Ambiente |
| `project_name` | `string` | Sim | Nome do projeto |

**Outputs:**

| Nome | Descrição |
|---|---|
| `instance_id` | ID da instância EC2 |
| `public_ip` | IP público da instância |
| `private_ip` | IP privado da instância |

**Exemplo de uso:**

```hcl
module "api_server" {
  source = "../../modules/ec2"

  instance_name      = "technova-dev-api"
  ami_id             = "ami-0c02fb55956c7d316"
  subnet_id          = module.vpc.public_subnet_ids[0]  # ← Composição com módulo VPC
  security_group_ids = [module.api_sg.sg_id]            # ← Composição com módulo SG
  key_name           = "technova-key"
  environment        = "dev"
  project_name       = "technova"
}
```

---

### Módulo RDS (`modules/rds/`)

**Descrição:** Cria um DB Subnet Group e uma instância RDS PostgreSQL nas subnets privadas.

**Inputs:**

| Nome | Tipo | Obrigatório | Descrição |
|---|---|---|---|
| `db_name` | `string` | Sim | Nome do banco de dados |
| `db_username` | `string` | Sim | Usuário master |
| `db_password` | `string` (sensitive) | Sim | Senha master |
| `subnet_ids` | `list(string)` | Sim | IDs das subnets para o DB Subnet Group |
| `security_group_ids` | `list(string)` | Sim | IDs dos Security Groups |
| `instance_class` | `string` | Não | Classe da instância (padrão: `db.t3.micro`) |
| `environment` | `string` | Sim | Ambiente |
| `project_name` | `string` | Sim | Nome do projeto |

**Outputs:**

| Nome | Descrição |
|---|---|
| `db_endpoint` | Endpoint de conexão com o banco |
| `db_name` | Nome do banco de dados |
| `db_port` | Porta do banco de dados |

**Exemplo de uso:**

```hcl
module "database" {
  source = "../../modules/rds"

  db_name            = "technova_dev"
  db_username        = "technovaadmin"
  db_password        = var.db_password  # Nunca coloque a senha diretamente
  subnet_ids         = module.vpc.private_subnet_ids  # ← Composição com módulo VPC
  security_group_ids = [module.rds_sg.sg_id]          # ← Composição com módulo SG
  environment        = "dev"
  project_name       = "technova"
}
```

---

## Como Usar — Criar um Novo Ambiente

1. Copie a pasta `environments/dev/` para `environments/prod/`
2. Altere os CIDRs no `main.tf` para evitar conflitos (ex: `10.2.0.0/16`)
3. Atualize o `terraform.tfvars` com os valores do novo ambiente
4. Execute:

```bash
cd environments/prod
terraform init
terraform validate
terraform plan
terraform apply
```

---

## Pré-requisitos

- **Terraform** >= 1.0
- **AWS CLI** configurado com credenciais válidas
- **Key Pair** criado no AWS EC2 com o nome informado em `key_name`
- Credenciais do AWS Academy Learner Lab carregadas via `source aws-creds.sh`

---

## Estrutura do Projeto

```
aula-06/
├── README.md
├── .gitignore
├── modules/
│   ├── vpc/               # VPC, subnets dinâmicas (for_each), IGW, route tables
│   ├── security-group/    # Security Group genérico com regras dinâmicas
│   ├── ec2/               # Instância EC2
│   └── rds/               # Instância RDS PostgreSQL + DB Subnet Group
└── environments/
    ├── dev/               # Ambiente de desenvolvimento (CIDRs 10.0.x.x)
    └── staging/           # Ambiente de homologação (CIDRs 10.1.x.x)
```

---

## Comparação entre Ambientes

| Aspecto | Dev | Staging |
|---|---|---|
| VPC CIDR | `10.0.0.0/16` | `10.1.0.0/16` |
| Subnets Públicas | `10.0.1.0/24`, `10.0.2.0/24` | `10.1.1.0/24`, `10.1.2.0/24` |
| Subnets Privadas | `10.0.3.0/24`, `10.0.4.0/24` | `10.1.3.0/24`, `10.1.4.0/24` |
| EC2 | t2.micro | t2.micro |
| RDS | db.t3.micro | db.t3.micro |
| DB Name | `technova_dev` | `technova_staging` |
| Naming | `technova-dev-*` | `technova-staging-*` |
