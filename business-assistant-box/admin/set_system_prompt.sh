#!/bin/bash
BASE_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$BASE_PATH/.env"

TOKEN=$(curl -s -X POST http://localhost:3000/api/v1/auths/signin \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"lalohambrickday@gmail.com\",\"password\":\"Zarias1998!!!\"}" \
  | python3 -c "import sys,json; print(json.load(sys.stdin).get('token','FAILED'))")

echo "Token: ${TOKEN:0:30}..."

PROMPT="You are the Business Assistant for Pinnacle Insurance Group, an independent insurance agency in Fort Worth, TX owned by Sandra Mitchell. You help the business owner manage daily operations, answer questions from company knowledge, and draft communications. Be professional, concise, and helpful. Cite your source document when answering from business knowledge. Rules: Never send emails, delete records, move money, or sign anything without approval. Never fabricate facts. If you do not have the information, say so."

# Try creating a model override entry with system prompt
RESULT=$(curl -s -X POST http://localhost:3000/api/v1/models/create \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"id\":\"llama3.2:latest\",\"name\":\"llama3.2:latest\",\"params\":{\"system\":\"$PROMPT\"}}")
echo "Create result: $RESULT" | head -c 200

# Also try the update endpoint
RESULT2=$(curl -s -X POST http://localhost:3000/api/v1/models/update \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "{\"id\":\"llama3.2:latest\",\"params\":{\"system\":\"$PROMPT\"}}")
echo ""
echo "Update result: $RESULT2" | head -c 200
