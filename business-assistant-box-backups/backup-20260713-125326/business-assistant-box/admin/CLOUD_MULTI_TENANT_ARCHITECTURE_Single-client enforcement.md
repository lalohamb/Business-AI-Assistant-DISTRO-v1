Single-client enforcement is possible. Here's how it works:

Files Created/Modified:
license_check.sh — New. Shared library that all scripts source. Reads .license file, enforces limits.

.license — New. Controls the tier. Single-client by default:

TIER=single
MAX_CLIENTS=1

Copy
switch_client.sh — Modified. Now checks license before allowing a switch.

post_install_client_setup.sh — Modified. Now blocks onboarding multiple clients on a single-client license.

CLOUD_MULTI_TENANT_PRICING_TIERS.md — Updated. Separates single ($2,500/yr) from multi-client ($4,500/yr) license.

How it enforces:
Action	Single License	Multi License
Onboard 1 client	✅	✅
Onboard 2+ clients	❌ blocked	✅
Switch between clients	❌ blocked	✅
Use cloud tier	N/A (we control infra)	N/A
The enforcement is "honor system plus friction" — the code is readable (they bought it), but the scripts actively refuse, and the license terms are the legal backstop. This is the same model tools like Sidekiq, Laravel Spark, and Metabase use.