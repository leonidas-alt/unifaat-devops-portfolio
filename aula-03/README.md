# Aula 03 — Terraform + IAM | Emilly Santos de Oliveira (4023575)

## Design da Estrutura IAM

A arquitetura do IAM criada para a **TechNova** foi elaborada garantindo a segregação clara de responsabilidades via RBAC (Role-Based Access Control):

- **Grupos Criados**:
  - `developers`: Destinado ao time de desenvolvimento básico e estagiários. Recebe acesso somente leitura para repositórios S3 (`technova-*`) e uma política de proteção explícita contendo negação para ações de exclusão.
  - `platform-eng`: Destinado à engenharia de plataforma. O grupo garante privilégios operacionais sobre infraestrutura, como gerenciar ciclo de vida de instâncias EC2 e operações de leitura/escrita no S3.

- **Separação de Acessos**:
  - `juliana-dev`: Pertence ao grupo `developers`, permitindo a leitura de buckets sem expor a infraestrutura.
  - `rafael-platform`: Possui associação dupla (`developers` e `platform-eng`), obtendo permissões operacionais completas para gerenciar instâncias e armazenamentos.
  - `lucas-intern`: Associado ao grupo `developers`, herdando a restrição de segurança e impossibilidade de realizar ações destrutivas.

---

## Princípio do Menor Privilégio

O **Princípio do Menor Privilégio (PoLP)** estabelece que qualquer entidade (usuário, serviço ou aplicação) deve possuir apenas os acessos estritamente necessários para desempenhar suas funções e nada além disso.

### Exemplos de Aplicação no Código:
1. **Restrição de Ações em EC2 com `Condition`**: A política `ec2-s3-full` permite iniciar ou parar apenas instâncias que contenham a tag `Project = TechNova`, impedindo ações em instâncias de outros times/projetos.
2. **Deny Explícito e Prefixo de Buckets**: A política de S3 não fornece acesso a todo o S3 (`*`), restringindo o recurso ao wildcard `arn:aws:s3:::technova-*`. Adicionalmente, aplicou-se a política `deny-destructive` para bloquear explicitamente a exclusão de buckets e encerramento de instâncias.

### Riscos da Política `AmazonS3FullAccess`:
Ao utilizar `AmazonS3FullAccess`, o usuário ganha permissões irrestritas em qualquer bucket da conta AWS, podendo listar, alterar permissões (ACLs/Bucket Policies), deletar dados ou excluir buckets inteiros de produção sem rastro prévio. A custom policy garante governança sobre o ciclo de vida dos dados.

---

## Diagrama de Permissões

```text
[ Usuários IAM ]
  ├── juliana-dev ────► [ Group: developers ] ──┬──► (Policy: s3-read) ─────────► S3 (technova-*) [GetObject/List]
  ├── lucas-intern ───► [ Group: developers ] ──┴──► (Policy: deny-destructive) ─► S3 / EC2 [DENY Delete/Terminate]
  │
  └── rafael-platform ─┬─► [ Group: developers ]
                       └─► [ Group: platform-eng ] ──► (Policy: ec2-s3-full) ───► EC2 [Start/Stop (Tag: TechNova)]
                                                                               └──► S3 [Read/Write]

[ Service Role ]
  (EC2 Instance) ──► [ Instance Profile ] ──► [ Role: ec2-role ] ──► (Policy: ec2-s3-app-data) ──► S3 (technova-app-data-*)