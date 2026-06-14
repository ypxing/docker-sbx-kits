#!/usr/bin/env bash
exec 2>>/tmp/pre-bash-hook.log
input=$(cat)
echo "[pre-bash] input: $input" >&2
cmd=$(echo "$input" | jq -r '.tool_input.command // empty' 2>/dev/null) || cmd=""
echo "[pre-bash] cmd: $cmd" >&2

if echo "$cmd" | grep -qE 'make .*(deploy)' \
|| echo "$cmd" | grep -qE 'git push' \
|| echo "$cmd" | grep -qE '(^|[;&|] *)(sudo )?aws ' \
|| echo "$cmd" | grep -qE 'docker compose .*(deploy)' \
|| echo "$cmd" | grep -qE '(^|[;&|] *)(sudo )?rm -rf ' \
|| echo "$cmd" | grep -qE '(cat|head|tail|less|more|bat|source|\.) +(\S*/)*\.(env|npmrc|yarnrc)'; then
  echo '{"decision": "block", "reason": "Blocked: make *deploy*, git push, aws, docker compose *deploy*, rm -rf, reading .env/.npmrc/.yarnrc files"}'
else
  echo '{"decision": "allow"}'
fi
