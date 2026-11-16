# FUTARI

ふたりだけの小さな居場所。HTML prototype with Supabase Auth integration scaffold.

## Files
- `index.html`: responsive app UI and username/password auth client
- `supabase-config.js`: public Supabase URL + anon/publishable key (fill in locally/repository)
- `supabase/schema.sql`: initial profiles table, RLS, and auth trigger

## Supabase setup
1. Create a Supabase project.
2. In SQL Editor, run all of `supabase/schema.sql`.
3. In Authentication settings, turn OFF email confirmations. FUTARI currently maps each username to an internal synthetic address (`<username>@login.futari.invalid`) so users do not enter an email address.
4. In Project Settings -> API, copy the Project URL and anon/publishable key into `supabase-config.js`.
5. Never put the `service_role` or secret key in frontend files.
6. Deploy the GitHub Pages site and test registration/login.

## Important limitations
- Synthetic email login means password reset by email is not available yet. Add a verified recovery email flow before treating this as a production account system.
- The public anon key is not a secret; database safety depends on RLS. Never disable RLS or add broad public policies.
- Room invitation, two-member access control, and real-time chat are not implemented yet.
