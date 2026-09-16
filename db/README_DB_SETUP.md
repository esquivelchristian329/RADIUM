# RADIUM + Supabase Database Setup

## Recommended architecture
RADIUM remains **local-first**. The current browser/localStorage tournament engine continues to work offline. Supabase becomes the shared source of truth when configured, with Realtime used for matches/LED wall and a sync queue added during the migration phase.

## 1. Create Supabase project
Create a Supabase project and keep the project URL and browser **anon/publishable key**. Do **not** put the service_role key in RADIUM.

## 2. Create the database
Open **SQL Editor** in Supabase and run:

`db/schema.sql`

If Supabase reports that a Realtime table is already in the publication, that particular `alter publication ... add table` statement can be skipped.

## 3. Configure RADIUM
Copy:

`db/supabase-config.example.js`

to:

`db/supabase-config.js`

and set your project URL and anon/publishable key.

Then load `db/supabase-config.js` before `js/supabase-db.js` in the application pages.

## 4. Authentication
Use Supabase Auth for Admin/Official/Table Official/Display accounts. Create the first account in Supabase Auth, then create its `profiles` row and `tournament_users` membership as an admin.

Example after creating a user:

```sql
insert into profiles (id, full_name, role)
values ('AUTH_USER_UUID', 'Tournament Administrator', 'admin');

insert into tournament_users (tournament_id, user_id, role)
values ('TOURNAMENT_UUID', 'AUTH_USER_UUID', 'admin');
```

## 5. Migration order
Do not migrate everything at once. Recommended order:

1. tournaments
2. teams
3. players
4. categories/category_players
5. courts
6. matches/brackets
7. combative match results
8. Anyo judge scores + deductions
9. audit logs
10. LED wall + reports + medal tally

## 6. Offline behavior
The final version should use IndexedDB as the local cache/sync queue. A score submitted while offline must be stored locally first, then synchronized when connectivity returns. Never require internet just to run a live match.

## 7. Security rules
- Browser uses only anon/publishable key.
- Admin/Official permissions are enforced by Supabase Auth + RLS, not merely by hiding buttons.
- Official PIN is not a database authorization mechanism; it can remain as an application-level tournament lock, while user roles provide actual authorization.
- Never expose service_role in HTML/JS.

## 8. Next implementation step
The current `supabase-db.js` is a non-breaking bridge. The next code pass should replace the existing localStorage CRUD one module at a time with DB-backed repositories and an IndexedDB sync queue. This avoids breaking the working bracket/scoreboard logic while moving the data layer to Supabase.
