-- Poker is het eerste spel hier waar geld tussen ACCOUNTS beweegt. Alle andere spellen
-- gaan tegen het huis: wat je wint komt uit de kas en wat je verliest gaat erheen. Aan een
-- pokertafel komt het van de speler naast je.
--
-- Dat botst met de sprintranglijst. Die rekent je winst als saldo-nu min saldo-aan-het-
-- begin, en beloont de nummer één met een VIP-pas. Twee vrienden die aan een privétafel
-- gaan zitten en de fiches van de een naar de ander schuiven, zetten die ander zo bovenaan
-- zonder dat er ook maar iets gewonnen is. Netto over het tweetal is het nul; voor de
-- ranglijst is het een pas.
--
-- Vandaar deze twee dingen:
--
--  1. Per speler wordt bijgehouden wat poker deze sprint met zijn saldo heeft gedaan:
--     alles wat van tafel terugkwam min alles wat erop ging. Daarmee is de ranglijst te
--     corrigeren -- zie de view onderaan.
--  2. Elke verplaatsing komt in een grootboek. Dat lost afspraken tussen spelers niet op
--     (geen enkele pokersite kan dat), maar maakt het wel zichtbaar: een vraag naar grote
--     eenzijdige stromen tussen twee vaste namen is één regel.
--
-- Draai dit ná sql/poker_rpc.sql.

alter table public.profiles
  add column if not exists poker_net numeric not null default 0,
  add column if not exists poker_net_sprint bigint;

create table if not exists public.pk_ledger (
  id        bigserial primary key,
  at        timestamptz not null default now(),
  sprint    bigint not null,
  lobby_id  bigint,
  user_id   uuid not null,
  username  text not null,
  -- 'sit' is negatief (van het saldo af), 'leave' positief (er weer op).
  kind      text not null,
  amount    integer not null
);
create index if not exists pk_ledger_sprint on public.pk_ledger (sprint, user_id);

revoke all on public.pk_ledger from anon, authenticated;
alter table public.pk_ledger enable row level security;

-- Het grootboek is niet geheim, maar ook niet iets om rond te strooien: alleen je eigen
-- regels, zodat je kunt narekenen wat poker met je saldo heeft gedaan.
create or replace view public.pk_my_ledger
with (security_invoker = false, security_barrier = true) as
  select l.at, l.sprint, l.kind, l.amount
    from public.pk_ledger l
   where l.user_id = auth.uid();

grant select on public.pk_my_ledger to authenticated;

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
