# IA no CI/CD — Análise Crítica

**Aula 09 — Docker Registry e IA no CI/CD**  
**Aluno:** Emilly Santos de Oliveira  
**RA:** 4023575  
**Data:** outubro/2026

---

## 1. Por que Amazon ECR?

O projeto TechNova usa AWS como infraestrutura principal. Escolher o **Amazon Elastic Container Registry (ECR)** como registry é a opção de menor fricção operacional nesse contexto.

### Comparação com alternativas

| Critério | Amazon ECR | Docker Hub | GitHub Container Registry (ghcr.io) |
|----------|-----------|------------|--------------------------------------|
| Integração com AWS | Nativa (IAM, ECS, EC2) | Requer credenciais extras | Requer credenciais extras |
| Autenticação | Temporária via `aws ecr get-login-password` | Token permanente | PAT do GitHub |
| Latência no deploy | Baixa (mesma rede AWS) | Alta (internet pública) | Média |
| Custo no Learner Lab | Incluso no Lab | Free tier limitado | Free tier limitado |
| Controle de acesso | Policies IAM granulares | Limitado no tier gratuito | Integrado ao GitHub |
| Scan de vulnerabilidades | Nativo (scan on push) | Pago | Dependência externa |

### Restrições do Learner Lab

O AWS Academy Learner Lab **não permite criar usuários/grupos/roles IAM**. Por isso:

- A autenticação usa as **credenciais temporárias da sessão** (`aws_access_key_id`, `aws_secret_access_key`, `aws_session_token`).
- Essas credenciais **expiram a cada ~4 horas** — o fluxo principal de push é o script local `ecr-push.sh`.
- O workflow `ci.yml` funciona somente enquanto os Secrets do GitHub estiverem atualizados com credenciais válidas.

---

## 2. Estratégia de Tagging

Três categorias de tags são publicadas para cada imagem:

### `sha-<7 caracteres>`
```
sha-a3f91c2
```
- Rastreabilidade exata: cada tag aponta para um commit específico.
- Permite **rollback cirúrgico**: `docker pull <uri>:sha-a3f91c2`.
- Imutável por convenção — nunca deve ser re-publicada com conteúdo diferente.

### `latest`
```
latest
```
- Conveniência para ambientes de desenvolvimento e testes rápidos.
- **Não deve ser usada em produção** — é mutável e pode apontar para conteúdos diferentes ao longo do tempo.

### Semver (`M.m.p`, `M.m`, `M`)
```
1.2.3   ← versão exata
1.2     ← floating patch
1       ← floating minor+patch
```
- Habilitado apenas quando existe uma **git tag** no formato `v*.*.*` no commit.
- Permite que sistemas downstream fixem compatibilidade (ex: `image: technova-api:1`).
- Segue o padrão do Docker Hub oficial para imagens públicas.

**Por que três níveis semver?** Permite que o consumidor escolha o nível de estabilidade:
- `1.2.3` = controle total, sem atualizações automáticas.
- `1.2` = recebe patches automaticamente.
- `1` = recebe minor + patches automaticamente.

---

## 3. Padrões Verificados pelo AI Review

O script `.github/scripts/ai-review.js` analisa o diff de cada PR e aplica 13 regras em três níveis de severidade.

### CRITICAL (bloqueiam o PR)

| ID | Padrão | Referência |
|----|--------|-----------|
| `hardcoded-secret` | Credenciais/tokens hardcoded no código (`password=`, `apikey=`, etc.) | CWE-798 / OWASP A07 |
| `eval-usage` | Uso de `eval()` — execução arbitrária de código | CWE-95 / OWASP A03 |
| `sql-injection` | Concatenação de variáveis do usuário em queries SQL | CWE-89 / OWASP A03 |
| `command-injection` | Input do usuário em `exec`/`spawn` via template literal | CWE-78 / OWASP A03 |
| `insecure-deserialization` | `JSON.parse()` direto em `req.body` sem validação | CWE-502 / OWASP A08 |

### WARNING (não bloqueiam, mas devem ser revisados)

| ID | Padrão | Referência |
|----|--------|-----------|
| `console-log` | `console.*()` em código de produção | Best Practice |
| `empty-catch` | Bloco `catch` vazio que silencia erros | CWE-390 |
| `todo-fixme` | Marcadores TODO/FIXME indicando dívida técnica | Best Practice |
| `prototype-pollution` | Acesso a `__proto__` com input externo | CWE-1321 |
| `regex-catastrophic` | Regex com potencial de ReDoS (backtracking catastrófico) | CWE-1333 |

### INFO (informativo, não impede merge)

| ID | Padrão | Referência |
|----|--------|-----------|
| `debugger-statement` | Instrução `debugger` esquecida no código | Best Practice |
| `http-not-https` | URL `http://` hardcoded (exceto localhost) | CWE-319 |
| `no-strict-equality` | Uso de `==` / `!=` em vez de `===` / `!==` | Best Practice |

---

## 4. Lógica do AI Review

O script não usa um LLM externo — realiza **análise estática local** do diff via expressões regulares. Isso foi uma escolha intencional dado o contexto do Learner Lab (sem acesso a Bedrock/OpenAI por custo e complexidade).

### Fluxo de análise

```
git diff (PR) → parseDiff() → linhas adicionadas (+)
    ↓
Para cada linha: testar contra 13 regras (RULES[])
    ↓
Gerar array de findings { severity, file, line, message, rule }
    ↓
Calcular summary { critical, warning, info, linesAnalyzed }
    ↓
Salvar JSON → workflow formata e posta comentário no PR
    ↓
Quality Gate: hasCritical? → exit 1 (bloqueia) : exit 0 (passa)
```

### Quality Gate

```
findings.some(f => f.severity === 'CRITICAL')
    → true  → process.exit(1) → workflow falha → PR bloqueado
    → false → process.exit(0) → PR pode ser mergeado
```

---

## 5. Quando Confiar na IA vs Quando Exige Review Humano

### Confiar na IA

- Detecção de padrões sintáticos conhecidos (eval, SQL concatenado, secrets visíveis)
- Formatação e convenções de código (console.log, debugger)
- Triagem inicial de PRs grandes — filtra o óbvio para o humano focar no importante
- Detecção consistente de vulnerabilidades documentadas (OWASP Top 10)

### Exige review humano

- **Lógica de negócio**: a IA não entende o contexto — um `if (user.role === 'admin')` pode estar certo ou errado dependendo das regras da aplicação.
- **Falsos positivos**: uma regex detectada como ReDoS pode ser perfeitamente segura no contexto de uso.
- **Arquitetura e design**: escolhas como normalização de banco, granularidade de API, separação de responsabilidades.
- **Testes de segurança dinâmicos**: a análise estática não substitui pentests ou DAST.
- **Dados sensíveis mascarados**: um segredo em variável de ambiente não aparece no diff — a IA não detecta o que não vê.
- **Mudanças de infraestrutura**: Terraform, Kubernetes manifests, IAM policies precisam de revisão humana especializada.

---

## 6. Limitações Identificadas

### Falsos Positivos

| Situação | Regra disparada | Por quê é FP |
|----------|-----------------|--------------|
| `const testPassword = 'abc123'` em arquivo de teste | `hardcoded-secret` | Senha de teste, não produção |
| `// TODO: melhorar later` em comentário antigo não modificado | `todo-fixme` | Linha de contexto, não nova |
| `console.log('Server started')` intencional no startup | `console-log` | Log de inicialização é aceitável |
| Regex de validação de CPF `/(^\d{3}\.?…)$/` | `regex-catastrophic` | Regex específica, não tem backtracking real |

### Falsos Negativos (o que a IA NÃO detecta)

- **IDOR** (Insecure Direct Object Reference): `GET /orders/:id` sem verificar se pertence ao usuário — parece código normal.
- **Race conditions**: lógica assíncrona problemática não tem padrão sintático óbvio.
- **Segredos em variáveis de ambiente**: não aparecem no diff.
- **Dependências com vulnerabilidades**: `npm audit` é necessário complementarmente.
- **Lógica de autorização incorreta**: `if (user.isAdmin)` pode estar errado por razões semânticas.
- **Injeção via headers HTTP**: `req.headers['x-forwarded-for']` não cai nos padrões atuais.

### Limitações estruturais

- Analisa apenas **linhas adicionadas** — não vê o contexto completo do arquivo.
- Baseada em regex — não faz parsing semântico da AST (Abstract Syntax Tree).
- Sem conhecimento do domínio da aplicação — não sabe o que é "normal" para TechNova.

---

## 7. Melhorias Futuras

1. **Integração com Amazon Bedrock (Claude)**: enviar o diff + contexto do arquivo para análise semântica real.
2. **Análise de AST com `@babel/parser`**: detectar problemas estruturais que regex não captura.
3. **Integração com `npm audit`**: incluir vulnerabilidades de dependências no mesmo comentário.
4. **Cache de resultados**: não re-analisar arquivos não modificados em pushes subsequentes.
5. **Whitelist por arquivo**: permitir suprimir regras específicas em arquivos de teste.
6. **Métricas de histórico**: rastrear evolução de achados ao longo do tempo no repositório.
