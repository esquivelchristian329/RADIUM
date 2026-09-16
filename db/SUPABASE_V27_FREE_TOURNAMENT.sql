-- RADIUM V27: FREE / PAID tournament billing mode
-- Supabase is authoritative. FREE affects financial UI/registration fees only.

alter table public.tournaments add column if not exists billing_mode text not null default 'PAID';
alter table public.tournaments add column if not exists currency text not null default 'PHP';
alter table public.tournaments drop constraint if exists tournaments_billing_mode_check;
alter table public.tournaments add constraint tournaments_billing_mode_check check (billing_mode in ('PAID','FREE'));
