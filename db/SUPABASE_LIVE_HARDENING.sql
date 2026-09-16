-- RADIUM V14 LIVE HARDENING
-- Run after db/schema.sql on a fresh project, or keep as the post-schema migration.

alter view public.live_match_queue set (security_invoker = true);
alter function public.radium_updated_at() set search_path = public;
alter function public.radium_jsonb_merge(jsonb,jsonb) set search_path = public;

revoke execute on function public.rls_auto_enable() from public, anon, authenticated;
revoke execute on function public.has_tournament_role(uuid,text[]) from public;
revoke execute on function public.is_tournament_member(uuid) from public;
revoke execute on function public.radium_save_match(uuid,jsonb) from public;
revoke execute on function public.radium_save_result(uuid,jsonb) from public;
revoke execute on function public.radium_save_tournament(uuid,jsonb) from public;
grant execute on function public.has_tournament_role(uuid,text[]) to authenticated;
grant execute on function public.is_tournament_member(uuid) to authenticated;
grant execute on function public.radium_save_match(uuid,jsonb) to authenticated;
grant execute on function public.radium_save_result(uuid,jsonb) to authenticated;
grant execute on function public.radium_save_tournament(uuid,jsonb) to authenticated;

-- Match/result RLS required by normalized cloud synchronization.
drop policy if exists matches_admin_all on public.matches;
create policy matches_admin_all on public.matches for all to authenticated
using (has_tournament_role(tournament_id,array['admin']))
with check (has_tournament_role(tournament_id,array['admin']));

drop policy if exists match_results_update on public.match_results;
create policy match_results_update on public.match_results for update to authenticated
using (exists(select 1 from public.matches m where m.id=match_results.match_id and has_tournament_role(m.tournament_id,array['admin','official','table_official'])))
with check (exists(select 1 from public.matches m where m.id=match_results.match_id and has_tournament_role(m.tournament_id,array['admin','official','table_official'])));

-- Performance indexes for normalized tournament queries.
create index if not exists idx_anyo_deductions_match_id on public.anyo_deductions(match_id);
create index if not exists idx_anyo_deductions_player_id on public.anyo_deductions(player_id);
create index if not exists idx_anyo_deductions_recorded_by on public.anyo_deductions(recorded_by);
create index if not exists idx_anyo_judge_scores_judge_id on public.anyo_judge_scores(judge_id);
create index if not exists idx_anyo_judge_scores_player_id on public.anyo_judge_scores(player_id);
create index if not exists idx_audit_logs_user_id on public.audit_logs(user_id);
create index if not exists idx_category_players_player_id on public.category_players(player_id);
create index if not exists idx_match_results_submitted_by on public.match_results(submitted_by);
create index if not exists idx_match_results_winner_player_id on public.match_results(winner_player_id);
create index if not exists idx_matches_blue_player_id on public.matches(blue_player_id);
create index if not exists idx_matches_court_id on public.matches(court_id);
create index if not exists idx_matches_red_player_id on public.matches(red_player_id);
create index if not exists idx_matches_winner_player_id on public.matches(winner_player_id);
create index if not exists idx_players_team_id on public.players(team_id);
create index if not exists idx_teams_tournament_id on public.teams(tournament_id);
create index if not exists idx_tournament_users_user_id on public.tournament_users(user_id);

-- IMPORTANT: radium_save_result() in older RADIUM builds had a PL/pgSQL variable
-- named match_id that shadowed the column in WHERE clauses. The current live
-- migration replaces it with v_match_id; keep the fixed version in the release
-- package rather than applying the older function definition again.
