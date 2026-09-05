FOOD & FUN — GITHUB PAGES + SUPABASE

FILES
- index.html — responsive shared web app
- config.js — put your Supabase URL and public publishable/anon key here
- schema.sql — run this entire file in Supabase SQL Editor
- manifest.json — mobile/PWA metadata
- README.txt — setup guide

ARCHITECTURE
GitHub Pages hosts the static web app.
Supabase provides:
- Anonymous authentication
- Postgres shared database
- Row Level Security
- Real-time database updates

SETUP
1. Create a Supabase project.
2. In Authentication > Sign In / Providers, enable Anonymous Sign-Ins.
3. Open SQL Editor and run schema.sql.
4. In Settings/API, copy the Project URL and public publishable key (or anon key).
5. Edit config.js with those two values.
6. Create a GitHub repository.
7. Upload index.html, config.js, manifest.json, schema.sql and README.txt to the root.
8. Enable GitHub Pages from the repository Settings > Pages.
9. Open the published URL.
10. Create a wallet. Give the Wallet ID to your partner.
11. Partner opens the same URL and joins using the Wallet ID.

SECURITY
- Only the public/publishable/anon key goes into config.js.
- NEVER put the service_role/secret key into GitHub Pages.
- Database access is protected by RLS membership policies.
- The join code is the shared wallet credential. Keep it private.
- Supabase anonymous users are persisted in each browser. Clearing browser data creates a new anonymous identity.

REAL-TIME
The app listens for changes to categories and activities through Supabase Realtime. Both phones must be online and connected to the same Wallet ID.
Supabase documents browser client initialization, anonymous sign-in, RLS, and Postgres Changes for this architecture.

VOUCHER LIMIT
The monthly voucher limit is enforced by a database trigger, not only by the interface.
For example, Fast Food = 5 means the database will reject the sixth Fast Food activity in the same month.
A transaction-level advisory lock prevents a simple simultaneous-write race.

RATING
1–10.

NO BUDGET LIMIT
Amount is optional and is only tracked for spending visibility.

NOTE ABOUT SHARED "SAVING"
The activity is saved to Supabase, not only to local browser storage. Therefore one phone's saved activity becomes visible to the other connected phone.

GitHub Pages is static hosting; it does not store the activities itself. Supabase is the shared backend.
