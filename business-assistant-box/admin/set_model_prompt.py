import sqlite3, json, time

PROMPT = "You are the Business Assistant for Pinnacle Insurance Group, an independent insurance agency in Fort Worth, TX owned by Sandra Mitchell. You help the business owner manage daily operations, answer questions from company knowledge, and draft communications. Be professional, concise, and helpful. Cite your source document when answering from business knowledge. Rules: Never send emails, delete records, move money, or sign anything without approval. Never fabricate facts. If you do not have the information, say so."

now_ts = int(time.time())
conn = sqlite3.connect('/app/backend/data/webui.db')
cur = conn.cursor()

cur.execute("SELECT id, params FROM model WHERE id='llama3.2:latest'")
row = cur.fetchone()
print("Existing model row:", row)

if row:
    params = json.loads(row[1]) if row[1] else {}
    params['system'] = PROMPT
    cur.execute("UPDATE model SET params=?, updated_at=? WHERE id='llama3.2:latest'",
                (json.dumps(params), now_ts))
    print("Updated existing model entry")
else:
    meta = json.dumps({"profile_image_url": "", "description": "Pinnacle Insurance Group Business Assistant", "capabilities": {}})
    params = json.dumps({"system": PROMPT})
    cur.execute(
        "INSERT INTO model (id, user_id, base_model_id, name, params, meta, is_active, updated_at, created_at) VALUES (?, 'system', 'llama3.2:latest', 'llama3.2:latest', ?, ?, 1, ?, ?)",
        ('llama3.2:latest', params, meta, now_ts, now_ts)
    )
    print("Created new model entry")

conn.commit()

# Verify
cur.execute("SELECT id, params FROM model WHERE id='llama3.2:latest'")
row = cur.fetchone()
if row:
    p = json.loads(row[1]) if row[1] else {}
    print("Verified system prompt:", p.get('system','NOT SET')[:80])
conn.close()
print("Done")
