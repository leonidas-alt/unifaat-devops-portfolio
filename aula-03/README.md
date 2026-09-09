# Aula 03 — Terraform + IAM | Emilly Santos de Oliveira (4023575)

## Design da Estrutura IAM

A arquitetura IAM criada para a **TechNova** foi elaborada com segregação clara de responsabilidades via RBAC (Role-Based Access Control), garantindo que cada usuário acesse apenas o que precisa para exercer sua função.

### Grupos Criados

- **`4023575-technova-developers`**: Destinado ao time de desenvolvimento e estagiários. Recebe acesso somente leitura nos buckets S3 com prefixo `technova-*` e uma política de proteção explícita (`deny-destructive`) que bloqueia qualquer ação destrutiva — deletar objetos, excluir buckets ou encerrar instâncias EC2.

- **`4023575-technova-platform-eng`**: Destinado à engenharia de plataforma. Concede privilégios operacionais sobre infraestrutura: gerenciar ciclo de vida de instâncias EC2 (com restrição por tag) e operações completas de leitura/escrita no S3.

### Separação de Acessos

- **`4023575-juliana-dev`**: Pertence apenas ao grupo `developers`, podendo ler buckets `technova-*` sem acesso à infraestrutura.
- **`4023575-rafael-platform`**: Associação dupla (`developers` + `platform-eng`), obtendo permissões operacionais completas para gerenciar instâncias e armazenamentos.
- **`4023575-lucas-intern`**: Associado ao grupo `developers`, herdando a restrição de segurança e a impossibilidade de realizar ações destrutivas.

---

## Princípio do Menor Privilégio

O **Princípio do Menor Privilégio (PoLP)** estabelece que qualquer entidade — usuário, serviço ou aplicação — deve possuir apenas os acessos estritamente necessários para desempenhar suas funções, e nada além disso.

### Exemplos de Aplicação no Código

1. **Restrição de Ações em EC2 com `Condition`**: A política `4023575-technova-ec2-s3-full` permite iniciar ou parar instâncias EC2 somente quando a instância possui a tag `Project = TechNova`. Isso impede que um engenheiro de plataforma da TechNova acidentalmente (ou intencionalmente) interrompa instâncias de outros projetos ou clientes rodando na mesma conta AWS.

2. **Deny explícito e prefixo de buckets**: A política `4023575-technova-s3-read` não concede acesso a todo o S3 (`*`), restringindo o recurso ao wildcard `arn:aws:s3:::technova-*`. Além disso, a política `4023575-technova-deny-destructive` bloqueia explicitamente ações de exclusão em S3 e encerramento de instâncias EC2 para todos os membros do grupo `developers` — incluindo o rafael, que também pertence a esse grupo.

### Riscos de usar `AmazonS3FullAccess`

Ao utilizar `AmazonS3FullAccess`, o usuário ganha permissões irrestritas em **qualquer** bucket da conta AWS, podendo listar, alterar permissões (ACLs/Bucket Policies), deletar dados ou excluir buckets inteiros de produção sem nenhuma restrição prévia. A custom policy `s3-read` garante governança granular: apenas `GetObject`, `ListBucket` e `GetBucketLocation` em buckets com prefixo `technova-*` — nada além do necessário.

---

## Diagrama de Permissões

```text
[ Usuários IAM ]
  ├── 4023575-juliana-dev ────► [ Group: developers ] ──┬──► (Policy: s3-read) ──────────► S3 (technova-*) [GetObject/List]
  ├── 4023575-lucas-intern ───► [ Group: developers ] ──┴──► (Policy: deny-destructive) ──► S3 / EC2 [DENY Delete/Terminate]
  │
  └── 4023575-rafael-platform ─┬─► [ Group: developers ]
                               └─► [ Group: platform-eng ] ──► (Policy: ec2-s3-full) ────► EC2 [Start/Stop (Tag: TechNova)]
                                                                                       └──► S3 (technova-*) [Read/Write]

[ Service Role ]
  (EC2 Instance) ──► [ Instance Profile: ec2-profile ] ──► [ Role: ec2-role ] ──► (Policy: ec2-s3-app-data) ──► S3 (technova-app-data-*)
```

---

## Comandos Utilizados

```bash
# Inicializa o diretório e baixa o provider AWS
terraform init

# Valida a sintaxe dos arquivos .tf
terraform validate

# Formata os arquivos seguindo o estilo padrão do Terraform
terraform fmt

# Exibe o plano de execução (recursos a criar/modificar/destruir)
terraform plan -var-file=terraform.tfvars

# Aplica a infraestrutura na AWS
terraform apply -var-file=terraform.tfvars

# Remove todos os recursos criados (executar após capturar evidências)
terraform destroy -var-file=terraform.tfvars
```

---

## Reflexão

A criação manual de IAM pelo Console AWS é viável para um único usuário em um ambiente de teste, mas se torna insustentável em equipes. Cada clique é um passo não documentado, impossível de auditar, difícil de reproduzir e sujeito a erro humano. Se dois engenheiros configurarem o mesmo recurso manualmente em contas diferentes, o resultado pode ser diferente sem que ninguém perceba.

Com Terraform, a infraestrutura vira código: versionado no Git, revisado via Pull Request, executado de forma idempotente e auditável por qualquer membro do time. Uma mudança de permissão num `policies.tf` gera um diff claro, passa por revisão e fica registrada no histórico. Se algo quebrar, o `terraform destroy` ou um `revert` no Git desfaz tudo em segundos.

Para uma equipe de DevOps, Terraform é a abordagem mais segura e auditável — especialmente em contextos regulatórios onde rastreabilidade de acesso é obrigatória.
