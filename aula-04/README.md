# Infraestrutura TechNova — Aula 04: VPC + EC2 Multi-AZ

**Aluno:** Emilly Santos de Oliveira  
**RA:** 4023575  
**Disciplina:** DevOps — UniFAAT 2026-2  
**Aula:** 04 — Terraform VPC + EC2 Multi-AZ

---

## Diagrama da Arquitetura

```
                         INTERNET
                             │
                    ┌────────▼────────┐
                    │ Internet Gateway│
                    │ (technova-igw)  │
                    └────────┬────────┘
                             │
              ┌──────────────▼──────────────────┐
              │         VPC: 10.0.0.0/16         │
              │         (technova-vpc)            │
              │                                  │
              │  ┌─────────────────────────────┐ │
              │  │     Route Table Pública      │ │
              │  │  0.0.0.0/0 → IGW             │ │
              │  └──────┬──────────────┬────────┘ │
              │         │              │           │
              │  ┌──────▼──────┐ ┌────▼────────┐  │
              │  │ Subnet Pub 1│ │Subnet Pub 2 │  │
              │  │10.0.1.0/24  │ │10.0.3.0/24  │  │
              │  │ us-east-1a  │ │ us-east-1b  │  │
              │  │             │ │             │  │
              │  │  ┌────────┐ │ │             │  │
              │  │  │  EC2   │ │ │  (futura    │  │
              │  │  │t2.micro│ │ │  instância) │  │
              │  │  │API:3000│ │ │             │  │
              │  │  └────────┘ │ │             │  │
              │  └─────────────┘ └─────────────┘  │
              │                                  │
              │  ┌─────────────┐ ┌─────────────┐  │
              │  │Subnet Priv 1│ │Subnet Priv 2│  │
              │  │10.0.2.0/24  │ │10.0.4.0/24  │  │
              │  │ us-east-1a  │ │ us-east-1b  │  │
              │  │  (banco de  │ │  (banco de  │  │
              │  │   dados)    │ │   dados)    │  │
              │  └─────────────┘ └─────────────┘  │
              │                                  │
              │  Security Groups:                 │
              │  ├── technova-api-sg              │
              │  │   ├── Ingress 22/TCP (SSH)     │
              │  │   └── Ingress 3000/TCP (API)   │
              │  └── technova-db-sg               │
              │      └── Ingress 5432/TCP (VPC)   │
              └──────────────────────────────────┘

  IAM:
  └── technova-ec2-role
      ├── AmazonS3ReadOnlyAccess
      └── technova-ec2-profile (Instance Profile)
```

---

## Pré-requisitos

- [Terraform](https://developer.hashicorp.com/terraform/downloads) >= 1.0
- [AWS CLI](https://aws.amazon.com/cli/) configurado com credenciais válidas
- Conta no AWS Academy Learner Lab com lab ativo
- Sistema Linux/macOS (para permissões SSH da chave `.pem`)

### Configurar credenciais do AWS Academy

```bash
# Copie as credenciais do painel do Learner Lab para:
~/.aws/credentials
```

---

## Como Usar

### 1. Inicializar o Terraform

```bash
cd aula-04/
terraform init
```

### 2. Revisar o plano de execução

```bash
terraform plan
# Para salvar evidência:
terraform plan > evidencia-plan.txt
```

### 3. Aplicar a infraestrutura

```bash
terraform apply
# Confirme digitando: yes
```

Após o apply, o Terraform exibe os outputs:

```
Outputs:

api_url               = "http://X.X.X.X:3000"
api_health_url        = "http://X.X.X.X:3000/health"
ssh_command           = "ssh -i ./technova-key.pem ec2-user@X.X.X.X"
ec2_public_ip         = "X.X.X.X"
vpc_id                = "vpc-XXXXXXXXX"
public_subnet_ids     = ["subnet-XXXXX", "subnet-XXXXX"]
private_subnet_ids    = ["subnet-XXXXX", "subnet-XXXXX"]
...
```

### 4. Aguardar o bootstrap

O User Data leva ~2 minutos para instalar Node.js e iniciar a API. Monitore com:

```bash
# SSH na instância e acompanhe o log
ssh -i ./technova-key.pem ec2-user@<IP>
sudo tail -f /var/log/user-data.log
```

---

## Como Testar

### Testar a API via curl

```bash
# Endpoint raiz — informações do projeto
curl http://<IP_PUBLICO>:3000

# Health check
curl http://<IP_PUBLICO>:3000/health

# Informações da infra
curl http://<IP_PUBLICO>:3000/info
```

Resposta esperada do `/`:
```json
{
  "message": "TechNova API — Aula 04 VPC + EC2 Multi-AZ",
  "status": "running",
  "aluno": "Emilly Santos de Oliveira",
  "ra": "4023575",
  "version": "1.0.0",
  "timestamp": "2026-09-08T...",
  "hostname": "ip-10-0-1-XXX",
  "platform": "linux",
  "nodeVersion": "v18.x.x"
}
```

### Testar SSH

```bash
ssh -i ./technova-key.pem ec2-user@<IP_PUBLICO>

# Na instância:
node --version          # v18.x.x
aws sts get-caller-identity
systemctl status technova-api
```

### Capturar evidências

```bash
# Evidência 1 — Plano do Terraform
terraform plan > evidencia-plan.txt

# Evidência 2 — Resposta da API
curl http://<IP>:3000        > evidencia-api.json
curl http://<IP>:3000/health >> evidencia-api.json

# Evidência 3 — SSH na instância
ssh -i ./technova-key.pem ec2-user@<IP> \
  "node --version && aws sts get-caller-identity" > evidencia-ssh.txt
```

---

## Como Destruir

> ⚠️ **Execute após capturar TODAS as evidências para evitar custos!**

```bash
terraform destroy
# Confirme digitando: yes
```

---

## Recursos Criados

| Recurso | Nome | Função |
|---|---|---|
| `aws_vpc` | `technova-vpc` | Rede virtual isolada (10.0.0.0/16) |
| `aws_subnet` (x2) | `technova-public-subnet-1/2` | Subnets públicas em 2 AZs (EC2, LB futuro) |
| `aws_subnet` (x2) | `technova-private-subnet-1/2` | Subnets privadas em 2 AZs (banco de dados) |
| `aws_internet_gateway` | `technova-igw` | Porta de saída para a internet |
| `aws_route_table` | `technova-public-rt` | Rota 0.0.0.0/0 → IGW para subnets públicas |
| `aws_route_table_association` (x2) | — | Associa RT pública às 2 subnets públicas |
| `aws_security_group` | `technova-api-sg` | Libera SSH (22) e API (3000) da internet |
| `aws_security_group` | `technova-db-sg` | Libera PostgreSQL (5432) apenas da VPC |
| `aws_iam_role` | `technova-ec2-role` | Role com S3 read-only para o EC2 |
| `aws_iam_instance_profile` | `technova-ec2-profile` | Associa a role à instância EC2 |
| `tls_private_key` | — | Gera par de chaves RSA 4096 bits |
| `aws_key_pair` | `technova-key` | Registra a chave pública na AWS |
| `local_sensitive_file` | `technova-key.pem` | Salva a chave privada localmente (0600) |
| `aws_instance` | `technova-api-ec2` | EC2 t2.micro com API Node.js rodando |

---

## Decisões Técnicas

### Por que Multi-AZ?

Alta disponibilidade: se uma Availability Zone sofrer uma falha (datacenter, energia, rede), a infraestrutura continua operacional na outra AZ. Com 2 AZs, o projeto está preparado para receber um Load Balancer no futuro sem precisar refatorar a rede.

### Por que separar subnets públicas e privadas?

Princípio do menor privilégio aplicado à rede: o banco de dados (e outros serviços internos) nunca fica exposto diretamente à internet. Apenas a camada de aplicação (EC2 na subnet pública) recebe tráfego externo. As subnets privadas só são alcançadas via VPC interna.

### Por que gp3 em vez de gp2?

O volume `gp3` oferece a mesma performance base do `gp2` com 20% de custo menor na AWS. Além disso, com `gp3` é possível provisionar IOPS e throughput de forma independente sem aumentar o tamanho do volume.

### Por que o Key Pair é gerado pelo Terraform?

Automação completa: nenhuma chave precisa ser criada manualmente antes do `terraform apply`. A chave privada é salva como `local_sensitive_file` com permissão `0600`, pronta para uso imediato via SSH.

### Por que usar systemd para a API?

Resiliência: o systemd reinicia a API automaticamente em caso de falha (`Restart=on-failure`). Além disso, a API sobe automaticamente quando a instância é reiniciada, sem intervenção manual.

---

## Estrutura do Projeto

```
aula-04/
├── providers.tf        # Terraform e provider AWS
├── variables.tf        # Declaração de variáveis
├── terraform.tfvars    # Valores das variáveis
├── networking.tf       # VPC, subnets, IGW, route tables
├── security_groups.tf  # SG da API e SG do banco
├── iam.tf              # Role, policy e instance profile
├── ec2.tf              # Key Pair, AMI e instância EC2
├── outputs.tf          # Outputs exportados
├── .gitignore          # Protege .tfstate e .pem
└── README.md           # Esta documentação
```

---

*Gerado com Terraform para a disciplina DevOps — UniFAAT 2026-2*
