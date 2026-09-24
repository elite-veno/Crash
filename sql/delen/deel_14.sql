-- ============================================================================
--  DEEL 14 VAN 14
-- ============================================================================
--
--  EERST DE EDITOR LEEGMAKEN: klik op "+ New query", of Ctrl+A en Delete. Staat er
--  nog iets van een vorige poging in -- zeker een half afgebroken stuk -- dan loopt
--  alles daarna scheef en krijg je een "syntax error" op een plek die niets zegt.
--
--  Plak dit pas NA deel 13. Die volgorde doet ertoe: dit deel gebruikt
--  wat de delen ervoor hebben aangemaakt.
--  Onderaan hoort dan "DEEL 14 VAN 14 IS HELEMAAL GEDRAAID" te staan.
--
--  Gaat er iets mis, draai dan niet verder -- kijk eerst wat er fout ging. Alles is
--  veilig om opnieuw te draaien, dus een deel nog een keer plakken kan altijd.
--
--  Uit: sql/poker_ledger.sql
--
--  DIT IS HET LAATSTE DEEL. Kijk hierna nog één ding na:
--  Settings -> API -> Exposed schemas moet ALLEEN `public` bevatten. Het schema
--  `poker` mag daar nooit bij -- daar liggen de holekaarten en de zaadjes.
-- ============================================================================


-- Bijschrijven, en meteen de stand van deze sprint bijwerken. Begint er een nieuwe sprint,
-- dan begint de teller opnieuw -- net als het saldo zelf.
create or replace function poker.note(p_uid uuid, p_naam text, p_lobby bigint,
                                      p_kind text, p_bedrag integer)
returns void language plpgsql security definer set search_path = '' as $$
declare v_sprint bigint := public.sprint_now();
begin
  insert into public.pk_ledger (sprint, lobby_id, user_id, username, kind, amount)
       values (v_sprint, p_lobby, p_uid, p_naam, p_kind, p_bedrag);

  update public.profiles
     set poker_net = case when poker_net_sprint is distinct from v_sprint
                          then p_bedrag else poker_net + p_bedrag end,
         poker_net_sprint = v_sprint
   where id = p_uid;
end;
$$;

revoke all on function poker.note(uuid, text, bigint, text, integer) from public, anon, authenticated;

-- De ranglijst zonder poker erin. `season_scores` bestond al en rekent met het kale saldo;
-- deze legt de pokerstroom ernaast, zodat wat je aan de tafels hebt verplaatst niet meetelt
-- voor de titel en de pas.
--
-- Let op: dit is een view OVER season_scores. Bestaat die niet, dan doet deze het ook niet.
do $$
begin
  if to_regclass('public.season_scores') is null then
    raise notice 'season_scores bestaat hier niet; sprint_scores wordt overgeslagen';
    return;
  end if;
  execute $v$
    create or replace view public.sprint_scores as
      select s.*,
             coalesce(p.poker_net, 0) as poker_net,
             (s.end_balance - s.start_balance)
               - case when p.poker_net_sprint = s.season then coalesce(p.poker_net, 0) else 0 end
               as gain_no_poker
        from public.season_scores s
        left join public.profiles p on p.username = s.username;
  $v$;
  execute 'grant select on public.sprint_scores to anon, authenticated';
end $$;

-- Zie je hieronder "DEEL 14 VAN 14 IS HELEMAAL GEDRAAID"? Dan is
-- dit deel compleet aangekomen en gelukt. Dat was de laatste.
select 'DEEL 14 VAN 14 IS HELEMAAL GEDRAAID' as klaar;
