---
name: minimax-usage
description: Check MiniMax API quota usage
---

# MiniMax Usage

Check your MiniMax API quota and usage.

## Usage

```bash
curl -s "https://api.minimax.io/v1/text/chatcompletion_v2" -H "Authorization: Bearer $MINIMAX_API_KEY" -H "Content-Type: application/json" -d '{"model":"MiniMax-M2.1","messages":[{"role":"system","content":"test"}],"max_tokens":1}'
```

Or check usage via the dashboard: https://platform.minimax.io
