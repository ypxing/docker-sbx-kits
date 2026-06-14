#!/usr/bin/env bash
input=$(cat)
# Copilot sends toolArgs (camelCase) or tool_input (PascalCase)
cmd=$(echo "$input" | jq -r '(try (.toolArgs | fromjson | .command) // .tool_input.command) // empty' 2>/dev/null) || cmd=""

if echo "$cmd" | grep -qE 'make .*(deploy)' \
|| echo "$cmd" | grep -qE 'git push' \
|| echo "$cmd" | grep -qE '(^|[;&|] *)(sudo )?aws ' \
|| echo "$cmd" | grep -qE 'docker compose .*(deploy)' \
|| echo "$cmd" | grep -qE '(^|[;&|] *)(sudo )?rm -rf ' \
|| echo "$cmd" | grep -qE '(cat|head|tail|less|more|bat|source|\.) +(\S*/)*\.(env|npmrc|yarnrc)' \
|| echo "$cmd" | grep -iqE '(UPDATE[[:space:]]+[^[:space:]]+[[:space:]]+SET[[:space:]]|DELETE[[:space:]]+FROM[[:space:]]|DROP[[:space:]]+(TABLE|DATABASE|SCHEMA|INDEX|VIEW|COLUMN)[[:space:]]|TRUNCATE[[:space:]]+(TABLE[[:space:]]+)?[^[:space:]]|ALTER[[:space:]]+TABLE[[:space:]]+[^[:space:]]+[[:space:]]+DROP[[:space:]])'; then
  printf '{"permissionDecision":"deny","permissionDecisionReason":"Blocked: make *deploy*, git push, aws, docker compose *deploy*, rm -rf, reading .env/.npmrc/.yarnrc files, destructive SQL (UPDATE/DELETE/DROP/TRUNCATE/ALTER DROP)"}\n'
else
  printf '{"permissionDecision":"allow"}\n'
fi
