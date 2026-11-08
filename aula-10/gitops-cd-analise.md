# GitOps + CD Pipeline — Análise Crítica

**Aluno:** Emilly Santos de Oliveira  
**RA:** 4023575  
**Disciplina:** DevOps — Centro Universitário UniFAAT  
**Aula:** 10 — Terraform Automatizado e CD Pipelines

---

## 1. Fluxo GitOps: por que plan no PR e apply no merge?

GitOps é o princípio de usar o repositório Git como única fonte da verdade para infraestrutura. Toda mudança passa por uma revisão versionada antes de ser aplicada.

### O fluxo adotado

```
[ desenvolvedor cria PR ]
         ↓
[ terraform-plan.yml dispara ]
         ↓
[ plan é postado como comentário no PR ]
         ↓
[ revisores aprovam o PR ]
         ↓
[ merge para main ]
         ↓
[ terraform-apply.yml dispara ]
         ↓
[ infraestrutura é atualizada ]
```

### Por que plan no PR (e não só no merge)?

O plan no PR cria um **gate de revisão**: antes de aprovar o merge, os revisores veem exatamente quais recursos serão criados, modificados ou destruídos. Isso evita surpresas — um `terraform apply` sem plan prévio pode destruir recursos que estavam fora do escopo da mudança.

Pontos práticos:
- Detecta erros de configuração antes de chegar à produção
- Permite revisão do custo estimado de novos recursos
- Registra o estado esperado da infraestrutura na thread do PR
- O comentário é atualizado (não duplicado) a cada novo push no PR

### Por que apply no merge (e não manualmente)?

Aplicar no merge garante que o estado do repositório `main` corresponde exatamente ao estado real da infraestrutura. Se o apply fosse manual, alguém poderia esquecer de executar, criando divergência entre o código e a infra real.

---

## 2. Autenticação no Learner Lab

### O que está implementado: credenciais de sessão como secrets

O AWS Academy Learner Lab fornece três credenciais temporárias por sessão:
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `AWS_SESSION_TOKEN`

Essas credenciais são armazenadas como GitHub Secrets e usadas pela action `aws-actions/configure-aws-credentials@v4`.

**Limitações:**
- Expiram a cada ~4 horas (ao fechar a sessão do Lab)
- Precisam ser atualizadas manualmente nos Secrets antes de cada execução
- Não é escalável para equipes — cada membro gerenciaria seus próprios secrets

### O padrão ideal em produção: OIDC + IAM Role

Em ambientes reais fora do Learner Lab, o correto é:

```yaml
- uses: aws-actions/configure-aws-credentials@v4
  with:
    role-to-assume: arn:aws:iam::ACCOUNT_ID:role/github-actions-role
    aws-region: us-east-1
```

Com OIDC:
- **Não há chaves estáticas** armazenadas nos Secrets
- O GitHub Actions autentica diretamente com a AWS via token OIDC
- A IAM Role tem política de trust que restringe ao repositório e branch específicos
- Tokens são de curta duração (15 minutos) e gerados automaticamente

**Por que o Lab não permite OIDC:**
O AWS Academy Learner Lab usa uma conta AWS restrita que não permite criar OIDC Providers (`aws iam create-open-id-connect-provider`) nem IAM Roles com trust policies para entidades externas. Por isso, usamos credenciais de sessão como solução viável dentro das restrições do ambiente.

---

## 3. Estratégia Recreate

A estratégia Recreate é a mais simples de deploy:

```
[ docker stop container_antigo ]
         ↓
[ docker rm container_antigo ]
         ↓
[ docker pull nova_imagem ]
         ↓
[ docker run novo_container ]
```

### Prós
- **Simples de implementar**: apenas 4 comandos Docker
- **Zero conflito de portas**: o container antigo libera a porta antes do novo subir
- **Estado limpo**: não há riscos de estado compartilhado entre versões
- **Fácil de entender e depurar**: o que você vê é o que está rodando

### Contras
- **Downtime**: há um período entre o stop do container antigo e o start do novo em que a API não responde
- **Sem rollback automático**: se o novo container falhar, é necessário intervenção manual
- **Sem zero-downtime**: inadequado para APIs que exigem alta disponibilidade

### Quando usar
- Ambientes de desenvolvimento e staging onde downtime é aceitável
- Serviços internos sem SLA rígido de disponibilidade
- Aprendizado e prototipagem, onde a simplicidade é prioridade
- Quando a carga é baixa e o deploy acontece em horários de menor uso

Para zero-downtime em produção, as estratégias adequadas são:
- **Blue-Green** (Aula 11): duas versões simultâneas, chaveamento via load balancer
- **Canary** (Aula 12): deploy gradual para um percentual dos usuários

---

## 4. Continuous Delivery vs Continuous Deployment

| Aspecto | Continuous Delivery | Continuous Deployment |
|---------|--------------------|-----------------------|
| Definição | Código sempre pronto para deploy; deploy é **acionado manualmente** | Todo merge que passa nos testes vai automaticamente para produção |
| Aprovação humana | **Sim** — alguém decide quando fazer o deploy | **Não** — o pipeline decide |
| Velocidade | Deploy quando necessário (horas ou dias) | Deploy contínuo (minutos após o merge) |
| Risco | Menor — humano faz validação final | Maior — exige testes automatizados muito confiáveis |
| Exemplo | CD pipeline com um botão "Deploy para produção" | Qualquer push para main vai para produção |
| Quando usar | Regulamentações, aprovações obrigatórias, ciclos de release definidos | Startups, produtos SaaS com alta cadência, equipes com cobertura de testes robusta |

### O que foi implementado nesta aula

O `cd.yml` implementa **Continuous Deployment**: qualquer push para `main` que altere os arquivos relevantes dispara automaticamente lint → test → build → push → deploy, sem aprovação humana intermediária.

Para converter em Continuous Delivery, bastaria adicionar um [GitHub Environment](https://docs.github.com/en/actions/deployment/targeting-different-environments/using-environments-for-deployment) com proteção de aprovação manual no job `deploy`.

---

## 5. Procedimento de Rollback

Em caso de falha no deploy, o procedimento está documentado detalhadamente em [`docs/runbook-rollback.md`](docs/runbook-rollback.md).

Resumo do fluxo:

1. Identificar o SHA da versão estável anterior (via ECR ou `git log`)
2. Login no ECR: `aws ecr get-login-password | docker login ...`
3. Pull da imagem anterior: `docker pull <REGISTRY>/technova-api:sha-<SHA_ANTERIOR>`
4. Recreate com a imagem anterior
5. Verificar health check
6. Abrir issue/PR para corrigir o código problemático

---

## 6. Limitações identificadas e melhorias

### Limitações atuais

| Limitação | Impacto | Causa |
|-----------|---------|-------|
| Credenciais de sessão expiram | Pipeline falha se secrets estiverem desatualizados | Restrição do Learner Lab |
| Estratégia Recreate tem downtime | API indisponível durante o deploy (~10-30s) | Simplicidade de implementação |
| EC2 única | Single point of failure | Custo (Free Tier) |
| Sem rollback automático | Intervenção manual necessária em falha | Fora do escopo desta aula |
| Health check externo depende de IP público | Falha se Security Group bloquear porta | Configuração de rede |

### O que eu melhoraria com mais tempo/recursos

1. **OIDC + IAM Role** no lugar de credenciais de sessão, eliminando a rotação manual
2. **Blue-Green deploy** (Aula 11) para zero downtime: duas instâncias com ALB fazendo o chaveamento
3. **Rollback automático**: se o health check falhar, o pipeline faz o rollback para a versão anterior automaticamente
4. **Notificação de deploy**: Slack ou Discord informando sucesso/falha com o SHA e link para o pipeline
5. **Terraform remote locking**: DynamoDB para evitar applies concorrentes
6. **Infracost**: estimativa de custo no comentário do PR para transparência financeira
7. **Ambientes separados**: staging e production com aprovação manual antes de produção
8. **Multi-AZ**: EC2 em duas AZs com Auto Scaling Group para alta disponibilidade
