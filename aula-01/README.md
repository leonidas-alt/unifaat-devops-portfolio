# Aula 01 — Fundamentos de Git e Docker

## O que aprendi
- O fluxo de trabalho utilizando branches isoladas (`feature branch`) antes de realizar a mesclagem.
- Importância do versionamento semântico de commits utilizando a convenção Conventional Commits.
- Isolamento de ambientes de execução criando imagens leves a partir de imagens Node Alpine.
- Gerenciamento do ciclo de vida de containers, mapeamento de portas e extração de logs.

## Comandos Git praticados
- `git checkout -b`
- `git commit -m`
- `git merge`
- `git push`

## Comandos Docker praticados
- `docker build`
- `docker run`
- `docker ps`
- `docker logs`

## Como executar este container
```bash
cd aula-01/app
docker build -t portfolio-aula01:1.0 .
docker run -d -p 3000:3000 portfolio-aula01:1.0
curl http://localhost:3000
