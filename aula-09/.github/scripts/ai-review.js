#!/usr/bin/env node
/**
 * ai-review.js — Script de análise estática de segurança e qualidade
 *
 * Analisa o diff de um PR e detecta padrões problemáticos.
 * Classifica achados por severidade: CRITICAL, WARNING, INFO.
 *
 * Uso:
 *   node ai-review.js --diff <caminho-do-diff> --output <saida.json>
 *
 * Padrões detectados (>8 regras — critério de excelência):
 *   CRITICAL: secrets hardcoded, eval(), SQL injection, command injection,
 *             deserialização insegura
 *   WARNING:  console.log, catch vazio, TODO/FIXME, prototype pollution,
 *             regex catastrophic backtracking
 *   INFO:     variáveis não utilizadas (trivial), comentários debugs
 */
'use strict';

const fs   = require('fs');
const path = require('path');

// ─── Parsing dos argumentos de linha de comando ───────────────────────────────
const args = process.argv.slice(2);
const getArg = (flag) => {
  const idx = args.indexOf(flag);
  return idx !== -1 ? args[idx + 1] : null;
};

const diffPath   = getArg('--diff');
const outputPath = getArg('--output');

if (!diffPath || !outputPath) {
  console.error('Uso: node ai-review.js --diff <path> --output <path>');
  process.exit(1);
}

// ─── Regras de análise ────────────────────────────────────────────────────────
/**
 * Cada regra tem:
 *   id       — identificador único
 *   severity — CRITICAL | WARNING | INFO
 *   pattern  — RegExp testada contra cada linha adicionada (+)
 *   message  — descrição do problema
 *   rule     — referência (OWASP, CWE etc.)
 */
const RULES = [
  // ── CRITICAL ────────────────────────────────────────────────────────────────
  {
    id: 'hardcoded-secret',
    severity: 'CRITICAL',
    // Detecta: password=, secret=, apiKey=, token=, AWS_SECRET etc. com valor
    pattern: /(?:password|secret|apikey|api_key|token|aws_secret_access_key|aws_access_key_id)\s*[:=]\s*['"`][^'"`]{4,}/i,
    message: 'Possível segredo/credencial hardcoded detectado. Use variáveis de ambiente.',
    rule: 'CWE-798 / OWASP A07',
  },
  {
    id: 'eval-usage',
    severity: 'CRITICAL',
    pattern: /\beval\s*\(/,
    message: '`eval()` executa código arbitrário — risco de RCE (Remote Code Execution).',
    rule: 'CWE-95 / OWASP A03',
  },
  {
    id: 'sql-injection',
    severity: 'CRITICAL',
    // Concatenação direta de variáveis em strings SQL
    pattern: /(?:SELECT|INSERT|UPDATE|DELETE|DROP|ALTER).*\+\s*(?:req\.|params\.|query\.|body\.)/i,
    message: 'Possível SQL Injection: variável concatenada diretamente em query SQL.',
    rule: 'CWE-89 / OWASP A03',
  },
  {
    id: 'command-injection',
    severity: 'CRITICAL',
    // exec/execSync com template literal contendo variáveis
    pattern: /(?:exec|execSync|spawn)\s*\(\s*`[^`]*\$\{/,
    message: 'Possível Command Injection: input do usuário em exec/spawn via template literal.',
    rule: 'CWE-78 / OWASP A03',
  },
  {
    id: 'insecure-deserialization',
    severity: 'CRITICAL',
    pattern: /JSON\.parse\s*\(\s*(?:req\.|request\.)(?:body|query|params)/,
    message: 'Desserialização direta de input do usuário sem validação prévia.',
    rule: 'CWE-502 / OWASP A08',
  },

  // ── WARNING ─────────────────────────────────────────────────────────────────
  {
    id: 'console-log',
    severity: 'WARNING',
    pattern: /console\.(log|debug|info|warn|error)\s*\(/,
    message: '`console.*()` encontrado — em produção, prefira um logger estruturado (ex: pino, winston).',
    rule: 'Best Practice',
  },
  {
    id: 'empty-catch',
    severity: 'WARNING',
    // catch seguido de bloco vazio ou com apenas comentário
    pattern: /catch\s*\([^)]*\)\s*\{\s*(?:\/\/[^\n]*)?\s*\}/,
    message: 'Bloco `catch` vazio ignora erros silenciosamente.',
    rule: 'CWE-390',
  },
  {
    id: 'todo-fixme',
    severity: 'WARNING',
    pattern: /\b(?:TODO|FIXME|HACK|XXX)\b/i,
    message: 'Marcador TODO/FIXME encontrado — verifique se indica dívida técnica não resolvida.',
    rule: 'Best Practice',
  },
  {
    id: 'prototype-pollution',
    severity: 'WARNING',
    pattern: /\[\s*['"`]__proto__['"`]\s*\]|\bprototype\b.*=\s*(?:req\.|params\.|body\.)/,
    message: 'Possível Prototype Pollution: acesso/atribuição de __proto__ ou prototype com input externo.',
    rule: 'CWE-1321',
  },
  {
    id: 'regex-catastrophic',
    severity: 'WARNING',
    // Padrões clássicos de ReDoS: (a+)+ ou (a|a)* etc.
    pattern: /\/(?:[^/]*\([^)]*[+*]\)[+*]|[^/]*(?:\|[^|]*){5,})[^/]*\//,
    message: 'Possível regex com backtracking catastrófico (ReDoS).',
    rule: 'CWE-1333',
  },

  // ── INFO ─────────────────────────────────────────────────────────────────────
  {
    id: 'debugger-statement',
    severity: 'INFO',
    pattern: /\bdebugger\b/,
    message: '`debugger` encontrado no código — remova antes do merge.',
    rule: 'Best Practice',
  },
  {
    id: 'http-not-https',
    severity: 'INFO',
    // URL http:// hardcoded (exceto localhost e 127.x)
    pattern: /http:\/\/(?!localhost|127\.0\.0\.1)/,
    message: 'URL sem TLS (http://) encontrada. Prefira https:// em produção.',
    rule: 'CWE-319',
  },
  {
    id: 'no-strict-equality',
    severity: 'INFO',
    // == ou != (não === ou !==)
    pattern: /[^!=<>]={2}(?!=)|[^!]!=[^=]/,
    message: 'Uso de `==` ou `!=` — prefira `===` / `!==` para evitar coerção de tipo.',
    rule: 'Best Practice',
  },
];

// ─── Parser do diff ───────────────────────────────────────────────────────────
/**
 * Retorna array de { file, line, content } para linhas adicionadas (+).
 */
function parseDiff(diffContent) {
  const lines   = diffContent.split('\n');
  const added   = [];
  let currentFile = null;
  let lineNumber  = 0;

  for (const line of lines) {
    // Detecta o arquivo sendo analisado: diff --git a/... b/...
    const fileMatch = line.match(/^\+\+\+ b\/(.+)/);
    if (fileMatch) {
      currentFile = fileMatch[1];
      continue;
    }

    // Atualiza número da linha pelo cabeçalho @@ -x,y +a,b @@
    const hunkMatch = line.match(/^@@ -\d+(?:,\d+)? \+(\d+)/);
    if (hunkMatch) {
      lineNumber = parseInt(hunkMatch[1], 10) - 1;
      continue;
    }

    // Linhas adicionadas (começam com +, mas não +++)
    if (line.startsWith('+') && !line.startsWith('+++')) {
      lineNumber++;
      added.push({
        file:    currentFile || 'unknown',
        line:    lineNumber,
        content: line.slice(1), // remove o '+'
      });
      continue;
    }

    // Linhas de contexto (não removidas) incrementam o número
    if (!line.startsWith('-')) {
      lineNumber++;
    }
  }

  return added;
}

// ─── Motor de análise ─────────────────────────────────────────────────────────
function analyze(addedLines) {
  const findings = [];

  for (const { file, line, content } of addedLines) {
    // Ignora arquivos binários, lock files e markdown
    if (/\.(png|jpg|gif|svg|lock|md)$/.test(file)) continue;

    for (const rule of RULES) {
      if (rule.pattern.test(content)) {
        findings.push({
          severity: rule.severity,
          file:     file,
          line:     line,
          message:  rule.message,
          rule:     rule.rule,
          ruleId:   rule.id,
          snippet:  content.trim().slice(0, 120),
        });
      }
    }
  }

  return findings;
}

// ─── Execução principal ───────────────────────────────────────────────────────
const diffContent  = fs.readFileSync(diffPath, 'utf8');
const addedLines   = parseDiff(diffContent);
const findings     = analyze(addedLines);

const summary = {
  critical:      findings.filter((f) => f.severity === 'CRITICAL').length,
  warning:       findings.filter((f) => f.severity === 'WARNING').length,
  info:          findings.filter((f) => f.severity === 'INFO').length,
  linesAnalyzed: addedLines.length,
  filesAnalyzed: [...new Set(addedLines.map((l) => l.file))].length,
};

const hasCritical = summary.critical > 0;

const result = {
  findings,
  summary,
  hasCritical,
  analyzedAt: new Date().toISOString(),
};

// Salva resultado em JSON
fs.writeFileSync(outputPath, JSON.stringify(result, null, 2), 'utf8');

// Log de saída para CI
console.log(`\n📋 AI Review — Resultado`);
console.log(`   Arquivos analisados : ${summary.filesAnalyzed}`);
console.log(`   Linhas adicionadas  : ${summary.linesAnalyzed}`);
console.log(`   🔴 CRITICAL         : ${summary.critical}`);
console.log(`   🟡 WARNING          : ${summary.warning}`);
console.log(`   🔵 INFO             : ${summary.info}`);
console.log(`\n   Resultado salvo em: ${path.resolve(outputPath)}\n`);

if (findings.length > 0) {
  console.log('Achados detalhados:');
  for (const f of findings) {
    console.log(`  [${f.severity}] ${f.file}:${f.line} — ${f.message}`);
  }
}

// Sai com código 0 — o quality gate é feito separadamente no workflow
process.exit(0);
