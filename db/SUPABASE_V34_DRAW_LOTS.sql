-- RADIUM V34 — Draw Lots / category-specific seeding
-- Supabase remains the authoritative source of tournament data.
-- Applied to the configured RADIUM Supabase project.

alter table public.category_players
  add column if not exists draw_number integer,
  add column if not exists draw_type text,
  add column if not exists drawn_at timestamptz;

alter table public.anyo_entries
  add column if not exists draw_order integer,
  add column if not exists draw_type text,
  add column if not exists drawn_at timestamptz;

create index if not exists idx_category_players_draw_number
  on public.category_players(category_id, draw_number);

create index if not exists idx_anyo_entries_draw_order
  on public.anyo_entries(category_id, draw_order);
