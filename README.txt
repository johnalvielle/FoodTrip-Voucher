FOOD & FUN SHARED VOUCHER WALLET — GITHUB + SUPABASE

UPLOAD THESE 5 FILES TO THE ROOT OF YOUR GITHUB REPOSITORY:
1. index.html
2. config.js
3. schema.sql
4. manifest.json
5. README.txt

IMPORTANT:
- index.html and config.js must be in the SAME folder.
- In config.js use ONLY the Supabase Project URL, for example:
  https://abcdefghijklmnop.supabase.co
- Do NOT add /rest/v1, /auth/v1, /storage/v1, /project, or other paths.
- Use the public publishable/anon key. NEVER use service_role/secret key.

SUPABASE:
1. SQL Editor → paste schema.sql → Run.
2. Authentication → Providers / Sign In → enable Anonymous Sign-Ins.
3. Settings → API → copy Project URL and public publishable/anon key into config.js.
4. Realtime: the schema enables activities and categories for Postgres Changes.

GITHUB PAGES:
Repository → Settings → Pages → Deploy from branch → main → /(root) → Save.
Open the generated Pages URL.

DIAGNOSTIC VERSION:
This version reports the exact stage of a connection failure instead of only showing “Setup error”.
