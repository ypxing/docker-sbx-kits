{
  "awsAuthRefresh": "aws sso login --profile sso-live --no-browser --use-device-code",
  "env": {
    "AWS_PROFILE": "sso-live",
    "CLAUDE_CODE_USE_BEDROCK": "1",
    "AWS_REGION": "${SSO_REGION}",
    "ANTHROPIC_DEFAULT_SONNET_MODEL": "${BEDROCK_SONNET_MODEL}",
    "ANTHROPIC_DEFAULT_OPUS_MODEL": "${BEDROCK_OPUS_MODEL}",
    "ANTHROPIC_DEFAULT_HAIKU_MODEL": "${BEDROCK_HAIKU_MODEL}"
  },
  "model": "${BEDROCK_SONNET_MODEL}"
}
