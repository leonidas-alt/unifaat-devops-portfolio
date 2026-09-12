# Aula 05 — RDS + Remote State com Terraform

**Aluno:** Emilly Santos de Oliveira  
**RA:** 4023575  
**Disciplina:** DevOps — Centro Universitário UniFAAT  
**Professor:** Alexandre Tavares  

---

## Objetivo

Provisionar a infraestrutura completa da TechNova com banco de dados gerenciado (RDS PostgreSQL) e remote state protegido (S3 + DynamoDB), demonstrando boas práticas de IaC em múltiplos arquivos `.tf` separados por responsabilidade.

---

## Arquitetura

```
                          ┌─────────────────────────────────────────┐
                          │         VPC  10.0.0.0/16                │
                          │                                          │
  Internet ──── IGW ────► │  ┌──── Subnet Pública ────────────────┐ │
                          │  │  10.0.1.0/24  (us-east-1a)         │ │
                          │  │  ┌─────────────────────────────┐   │ │
                          │  │  │  EC2 t2.micro               │   │ │
                          │  │  │  Amazon Linux 2023          │   │ │
                          │  │  │  SG: porta 22 + 3000        │   │ │
                          │  │  └──────────────┬──────────────┘   │ │
                          │  └─────────────────│──────────────────┘ │
                          │                    │ porta 5432         │
                          │  ┌── Subnets Privadas ────────────────┐ │
                          │  │  10.0.2.0/24  (us-east-1a)        │ │
                          │  │  10.0.3.0/24  (us-east-1b)        │ │
                          │  │  ┌─────────────────────────────┐  │ │
                          │  │  │  RDS PostgreSQL 15          │  │ │
                          │  │  │  db.t3.micro                │  │ │
                          │  │  │  SG: origem = SG do EC2 ★  │  │ │
                          │  │  └─────────────────────────────┘  │ │
                          │  └────────────────────────────────────┘ │
                          └─────────────────────────────────────────┘

Remote State:
  S3 Bucket ──── terraform.tfstate (versionado, encriptado, sem acesso público)
  DynamoDB ───── LockID (evita apply concorrente)
```

---

## Estrutura de Arquivos

```
aula-05/
├── backend/                  # Infraestrutura do Remote State (executar primeiro)
│   ├── main.tf               # S3 Bucket + DynamoDB
│   ├── variables.tf
│   ├── outputs.tf            # Imprime o nome do bucket para copiar no providers.tf
│   ├── terraform.tfvars      # ← ignorado pelo .gitignore
│   └── .gitignore
│
├── providers.tf              # Provider AWS + backend S3
├── variables.tf              # Todas as variáveis (db_password sensitive = true)
├── networking.tf             # VPC, subnets, IGW, route tables
├── security_groups.tf        # SG do EC2 + SG do RDS (★ bônus: SG reference)
├── rds.tf                    # DB Subnet Group + instância PostgreSQL 15
├── ec2.tf                    # Key pair + EC2 + user_data (★ bônus: auto-test)
├── iam.tf.disabled           # IAM Role + Instance Profile (★ bônus, desabilitado no AWS Academy)
├── outputs.tf                # Endpoints, IPs, comandos prontos
├── terraform.tfvars          # ← ignorado pelo .gitignore (contém db_password!)
└── .gitignore
```

---

## Requisitos Atendidos

### Obrigatórios

| Requisito | Arquivo | Status |
|-----------|---------|--------|
| VPC 10.0.0.0/16 | `networking.tf` | ✅ |
| 1 subnet pública (EC2) | `networking.tf` | ✅ |
| 2 subnets privadas em AZs diferentes (RDS) | `networking.tf` | ✅ |
| Internet Gateway + Route Table | `networking.tf` | ✅ |
| DB Subnet Group | `rds.tf` | ✅ |
| RDS PostgreSQL 15, db.t3.micro | `rds.tf` | ✅ |
| `multi_az = false` | `rds.tf` | ✅ |
| `publicly_accessible = false` | `rds.tf` | ✅ |
| `storage_encrypted = true` | `rds.tf` | ✅ |
| `skip_final_snapshot = true` | `rds.tf` | ✅ |
| EC2 t2.micro na subnet pública | `ec2.tf` | ✅ |
| Security Group EC2 (22 + porta API) | `security_groups.tf` | ✅ |
| Security Group RDS (porta 5432) | `security_groups.tf` | ✅ |
| S3 com encriptação + versionamento + Block Public Access | `backend/main.tf` | ✅ |
| DynamoDB com partition key LockID | `backend/main.tf` | ✅ |
| Backend S3 configurado com `encrypt = true` | `providers.tf` | ✅ |
| `sensitive = true` nas variáveis sensíveis | `variables.tf` | ✅ |
| `.gitignore` correto | `.gitignore` | ✅ |
| Tags em todos os recursos | todos os `.tf` | ✅ |
| Outputs úteis | `outputs.tf` | ✅ |

### Bônus Implementados ★

| Bônus | Implementação |
|-------|---------------|
| **Security Group por referência** | `security_groups.tf` — RDS permite porta 5432 apenas do `aws_security_group.ec2.id`, não do CIDR da VPC |
| **IAM Role para EC2** | `iam.tf.disabled` — configuração preparada, mas desabilitada no AWS Academy |
| **User data automatizado** | `ec2.tf` — instala `psql`, aguarda o RDS, testa conexão, cria tabela `orders`, salva evidência em `/var/log/rds-test.log` |

---

## Como Executar

### Pré-requisitos

- Terraform >= 1.0
- AWS CLI configurado (`aws configure`)
- Conta AWS com permissões para EC2, RDS, VPC, S3, DynamoDB, IAM

### Passo 1 — Backend (Remote State)

```bash
cd aula-05/backend/

# 1. Edite terraform.tfvars se necessário (região, RA)
# 2. Init e apply
terraform init
terraform apply

# 3. Copie o output "bucket_name" — você vai precisar no próximo passo
terraform output bucket_name
```

### Passo 2 — Atualizar o providers.tf

Edite `aula-05/providers.tf` e substitua `SEU-BUCKET-AQUI` pelo nome real do bucket:

```hcl
backend "s3" {
  bucket         = "technova-tfstate-4023575-abcd1234"  # ← nome real
  key            = "aula-05/terraform.tfstate"
  region         = "us-east-1"
  encrypt        = true
  dynamodb_table = "technova-terraform-lock"
}
```

### Passo 3 — Definir a senha do banco

Edite `aula-05/terraform.tfvars` e coloque uma senha forte:

```hcl
db_password = "MinhaS3nhaF0rte!2024"  # mínimo 16 caracteres
```

### Passo 4 — Infraestrutura Principal

```bash
cd aula-05/

terraform init        # inicializa providers e configura o backend S3
terraform validate    # valida a sintaxe
terraform fmt         # formata o código
terraform plan        # revisa o que será criado
terraform apply       # cria a infraestrutura (~15 min — RDS demora)
```

### Passo 5 — Verificar evidências

```bash
# Ver o resumo da infra
terraform output summary

# Verificar state no S3
aws s3 ls s3://technova-tfstate-4023575-05ebccce/aula-05/

# Ver o log de conexão automático (bônus)
$(terraform output -raw rds_test_log_command)

# Conectar ao EC2 e testar manualmente
ssh -i technova-key.pem ec2-user@$(terraform output -raw ec2_public_ip)

# Dentro do EC2 — conectar ao RDS
PGPASSWORD='SUA-SENHA' psql \
  -h $(terraform output -raw rds_address) \
  -p 5432 \
  -U technova_admin \
  -d technova_db \
  -c "SELECT * FROM orders;"
```

### Passo 6 — Destruir tudo após as evidências

```bash
# 1. Destruir infraestrutura principal
cd aula-05/
terraform destroy

# 2. Esvaziar o bucket S3 (obrigatório antes de destruir)
aws s3 rm s3://SEU-BUCKET --recursive

# Para deletar também as versões antigas:
aws s3api list-object-versions \
  --bucket SEU-BUCKET \
  --query 'Versions[].{Key:Key,VersionId:VersionId}' \
  --output text | \
  awk '{print $1, $2}' | \
  while read key version; do
    aws s3api delete-object --bucket SEU-BUCKET --key "$key" --version-id "$version"
  done

# 3. Destruir o backend
cd backend/
terraform destroy
```

---

## Decisões de Design

**Por que 1 subnet pública + 2 privadas (não 2+2)?**  
O exercício pede apenas 1 subnet pública para a EC2 e 2 privadas para o DB Subnet Group. Adicionar uma segunda subnet pública sem uso real seria código desnecessário.

**Por que SG reference no RDS em vez de CIDR da VPC? (★ bônus)**  
Usar `security_groups = [aws_security_group.ec2.id]` é mais seguro: apenas instâncias com aquele SG específico chegam ao banco. Com CIDR, qualquer recurso na VPC (incluindo futuras instâncias) teria acesso. É o princípio do menor privilégio aplicado a Security Groups.

**Por que `backup_retention_period = 0`?**  
Em lab, backups automáticos aumentam custo e não são necessários. Em produção, use pelo menos 7 dias.

**Por que o bucket é esvaziado antes do destroy?**  
O bucket é versionado e o backend é criado via `terraform_data`; por isso o state e as versões antigas devem ser removidos antes da destruição do backend.

---

## Conceitos Praticados

- **Remote State:** Separação entre estado local (perigoso) e remoto (S3), com proteção de concorrência via DynamoDB (State Locking).
- **RDS gerenciado:** AWS cuida de patches, backups, failover — você define apenas configuração e acesso.
- **DB Subnet Group:** Agrupa subnets em múltiplas AZs para o RDS saber onde pode colocar a instância (e o standby, se `multi_az = true`).
- **Security Group como recurso:** A referência `security_groups = [sg_id]` cria uma regra dinâmica que acompanha o ciclo de vida do SG — se o SG do EC2 mudar, a regra do RDS se adapta automaticamente.
- **`sensitive = true`:** Variáveis marcadas como sensíveis não aparecem em plain text no output do `terraform plan/apply`.

---

## Aprendizados

- O bloco `backend "s3"` não aceita variáveis — os valores precisam ser literais. Por isso o `outputs.tf` do backend imprime o snippet pronto para colar.
- O RDS demora cerca de 10–15 minutos para ficar disponível após o `apply`. O `user_data` usa `pg_isready` em loop para aguardar.
- Destruir na ordem certa é crucial: infra principal → esvaziar S3 → backend. Inverter a ordem deixa o bucket S3 orphan.
