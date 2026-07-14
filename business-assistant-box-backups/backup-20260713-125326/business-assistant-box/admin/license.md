# Enforcement Levels

| Level | How It Works | Pros | Cons |
|-------|-------------|------|------|
| Honor system | License file exists but nothing checks it | Zero friction, tracks who has what | No enforcement |
| Offline validation | install.sh checks license format/signature locally (e.g., HMAC-signed payload) | No server needed, works air-gapped | Can be bypassed by editing code |
| Phone-home | System pings your server on install or periodically to validate | Full control, can revoke licenses | Requires you to run a validation server |



My Recommendation
Start with offline signed licenses — good balance of real protection without infrastructure overhead:

package.sh generates a JSON payload ({id, issued_at, version, customer}) and signs it with a secret key (HMAC-SHA256)

The signed token goes into the package as LICENSE

install.sh verifies the signature before proceeding — if invalid, it exits

You keep a local licenses.json ledger tracking every issued license

## This means:

1. Each package is uniquely traceable

2. Install won't proceed without a valid license

3. No server infrastructure needed

4. You can upgrade to phone-home later if needed

## Questions Before I Build It
Who are you packaging for? (Paying customers, beta testers, yourself?)

Do you want a customer name/email baked into each license?

Should expired/revoked licenses be a thing, or just "issued = valid forever"?

Where do you want the license ledger stored? (Local file in the project, or somewhere else?)