# Trabalho em Aula — Aula 06: Módulos Terraform

**Aluno:** Emilly Santos de Oliveira  
**RA:** 4023575  
**Data:** 26/09/2026

## Parte 1 — Identificação de Duplicação

1. **Blocos de recursos duplicados entre dev e staging:**
   Os cinco blocos de módulos são idênticos em estrutura nos dois ambientes: `module "vpc"`, `module "api_sg"`, `module "rds_sg"`, `module "api_server"` e `module "database"`. A lógica de composição (quais outputs um módulo passa para o outro) é exatamente a mesma nos dois arquivos `main.tf`.

2. **O que muda entre dev e staging:**
   - CIDRs da VPC e das subnets (`10.0.x.x` em dev vs `10.1.x.x` em staging)
   - Nome do banco de dados (`technova_dev` vs `technova_staging`)
   - O valor da variável `environment` (`"dev"` vs `"staging"`), que impacta nomes e tags de todos os recursos
   - Os valores em `terraform.tfvars` (ami_id, key_name, db_password, etc.)

3. **Módulos que eu criaria (mín. 3):**
   - `modules/vpc` — cria VPC, subnets públicas/privadas, Internet Gateway e Route Tables
   - `modules/security-group` — cria um Security Group genérico e reutilizável com regras configuráveis via variável
   - `modules/ec2` — provisiona uma instância EC2 com AMI, tipo, subnet e SG parametrizáveis
   - `modules/rds` — cria instância RDS PostgreSQL com subnet group e SG parametrizáveis

4. **Variáveis (inputs) de cada módulo:**

   | Módulo           | Variáveis principais                                                                 |
   |------------------|--------------------------------------------------------------------------------------|
   | `vpc`            | `vpc_cidr`, `project_name`, `environment`, `subnets` (map com cidr, az e type)      |
   | `security-group` | `name`, `vpc_id`, `ingress_rules`, `egress_rules`, `environment`, `project_name`     |
   | `ec2`            | `instance_name`, `instance_type`, `ami_id`, `subnet_id`, `security_group_ids`, `key_name`, `environment`, `project_name` |
   | `rds`            | `db_name`, `db_username`, `db_password`, `subnet_ids`, `security_group_ids`, `instance_class`, `environment`, `project_name` |

5. **Outputs de cada módulo:**

   | Módulo           | Outputs                                                          |
   |------------------|------------------------------------------------------------------|
   | `vpc`            | `vpc_id`, `vpc_cidr`, `public_subnet_ids`, `private_subnet_ids`, `internet_gateway_id` |
   | `security-group` | `sg_id`, `sg_name`                                               |
   | `ec2`            | `instance_id`, `public_ip`, `private_ip`                         |
   | `rds`            | `db_endpoint`, `db_name`, `db_port`                              |

6. **Linhas para ambiente de produção (código atual vs com módulos):**

   Sem módulos, seria necessário reescrever todos os blocos `resource` de VPC, subnets, internet gateway, route tables, security groups, EC2 e RDS — algo em torno de **150–200 linhas** de HCL repetidas.

   Com módulos, o ambiente de produção exige apenas **~60 linhas** no `main.tf` (as mesmas chamadas `module "vpc"`, `module "api_sg"`, `module "rds_sg"`, `module "api_server"` e `module "database"` com os valores de prod), mais um `terraform.tfvars` com as variáveis específicas do ambiente.

---

## Parte 2 — Design de Módulos (Diagrama de Dependências)

```
┌─────────────────────────────────────────────────────┐
│                   environments/dev                  │
│                  environments/staging               │
│                                                     │
│  module "vpc"                                       │
│       │                                             │
│       ├──── vpc_id ────► module "api_sg"            │
│       │                       │                     │
│       ├──── vpc_id ────► module "rds_sg"            │
│       │                       │                     │
│       ├──── public_subnet_ids[0] ──┐                │
│       │                            ▼                │
│       │                   module "api_server" ◄─────┤ sg_id (api_sg)
│       │                                             │
│       └──── private_subnet_ids ──┐                  │
│                                  ▼                  │
│                         module "database" ◄─────────┤ sg_id (rds_sg)
└─────────────────────────────────────────────────────┘
```

- **Módulo criado primeiro e por quê:** O módulo `vpc` deve ser criado primeiro porque todos os outros dependem de seus outputs — os módulos de Security Group precisam do `vpc_id`, e os módulos EC2 e RDS precisam dos IDs de subnets que só existem após a VPC ser provisionada. O Terraform resolve essa ordem automaticamente pelo grafo de dependências implícitas.

- **Output da VPC que os Security Groups consomem:** `vpc_id` — tanto `module "api_sg"` quanto `module "rds_sg"` recebem `vpc_id = module.vpc.vpc_id` para saber em qual VPC criar o Security Group.

- **Quantos módulos o EC2 depende:** O módulo `api_server` (EC2) depende de **2 módulos**: `module.vpc` (para `public_subnet_ids[0]` como `subnet_id`) e `module.api_sg` (para `sg_id` como `security_group_ids`).

- **O que acontece com os outros módulos ao destruir a VPC:** A destruição falha ou causa cascata de erros, pois todos os recursos dos outros módulos (Security Groups, EC2, RDS) residem dentro da VPC. O Terraform detecta as dependências no state e destrói os recursos dependentes primeiro (EC2 → RDS → Security Groups → VPC), na ordem inversa de criação — ou bloqueia a operação se os recursos dependentes ainda existirem.

- **Vantagem de um módulo genérico de Security Group:** Um módulo genérico de SG aceita `ingress_rules` como variável (lista de objetos), permitindo criar tanto o SG da API (portas 80 e 22) quanto o SG do RDS (porta 5432) com **o mesmo módulo**, apenas passando regras diferentes. Isso elimina duplicação de código, centraliza a lógica de criação do SG em um único lugar e facilita a manutenção — uma mudança no módulo se propaga para todos os Security Groups que o utilizam.
