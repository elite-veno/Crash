-- ============================================================================
--  DEEL 5 VAN 14
-- ============================================================================
--
--  EERST DE EDITOR LEEGMAKEN: klik op "+ New query", of Ctrl+A en Delete. Staat er
--  nog iets van een vorige poging in -- zeker een half afgebroken stuk -- dan loopt
--  alles daarna scheef en krijg je een "syntax error" op een plek die niets zegt.
--
--  Plak dit pas NA deel 4. Die volgorde doet ertoe: dit deel gebruikt
--  wat de delen ervoor hebben aangemaakt.
--  Onderaan hoort dan "DEEL 5 VAN 14 IS HELEMAAL GEDRAAID" te staan.
--
--  Gaat er iets mis, draai dan niet verder -- kijk eerst wat er fout ging. Alles is
--  veilig om opnieuw te draaien, dus een deel nog een keer plakken kan altijd.
--
--  Uit: sql/poker_rpc.sql
-- ============================================================================


-- ---------- aan tafel gaan ----------
-- Fiches komen uit je saldo en gaan er weer heen. Ze worden nergens gemaakt.
create or replace function public.pk_sit(p_buyin integer)
returns json language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := auth.uid();
  v_lobby bigint;
  v_naam text;
  v_saldo numeric;
  v_koop integer;
  v_stoel smallint;
  v_zat integer;
begin
  if v_uid is null then raise exception 'not signed in'; end if;

  -- `id`, niet `lobby_id`. Zo heet de kolom in de echte my_lobby -- de pagina leest hem
  -- ook zo (lobbyPull: `LOBBY.id = r.id`). Hier stond eerst `l.lobby_id`, en omdat
  -- PL/pgSQL een kolomnaam pas bij het uitvoeren opzoekt, ging het aanmaken van deze
  -- functie gewoon goed en klapte daarna elke poging om te gaan zitten. De toetsen zagen
  -- het niet: de nagebouwde my_lobby in test_stub.sql had wél een kolom lobby_id.
  select l.id into v_lobby from public.my_lobby l limit 1;
  if v_lobby is null then raise exception 'join a table first'; end if;

  -- Eén tafel tegelijk, net als in pk_tick en pk_leave: aanschuiven raakt dezelfde rijen
  -- als het opruimen en het delen.
  perform pg_advisory_xact_lock(v_lobby);

  -- Eerst de sprintgrens, dan pas geld aanraken.
  --
  -- Op profiles zit een trigger die een achterstallig account terugzet naar 1000 zodra er
  -- iets naar die rij geschreven wordt. Deed je dat hier niet expliciet, dan gebeurde het
  -- alsnog -- maar midden in `balance = balance - inkoop`, en dan gooit de trigger die
  -- aftrek weg en zet er 1000 neer. De fiches werden daarna toch op tafel gezet: gratis
  -- inkopen, elke sprintgrens opnieuw. Een lege update laat de trigger zijn werk doen
  -- voordat er iets te rekenen valt; is er niets achterstallig, dan verandert er niets.
  update public.profiles set balance = balance where id = v_uid;

  -- Zit je er al? Dan mag je alleen bijkopen als je blut bent. Anders stond je vast: een
  -- speler die zijn stapel kwijt is heeft een rij met nul fiches, pk_tick deelt hem geen
  -- kaarten meer, en opstaan-en-weer-zitten was de enige uitweg. Bijkopen met fiches nog
  -- op tafel mag niet -- dat is midden in het spel je stapel vergroten.
  select pl.stack into v_zat from public.pk_players pl
   where pl.lobby_id = v_lobby and pl.user_id = v_uid for update;
  if v_zat is not null and v_zat > 0 then
    raise exception 'already seated';
  end if;
  if v_zat is not null and exists (
       select 1 from public.pk_rounds r
        join public.pk_seats st on st.round_id = r.id
       where r.lobby_id = v_lobby and r.settled_at is null and st.user_id = v_uid) then
    raise exception 'wait for the hand to finish';
  end if;

  -- De inkoop ligt tussen honderd en vijfhonderd: met een startsaldo van 1000 kan niemand
  -- zijn hele hebben en houden op één tafel zetten, en een tafel loopt niet leeg omdat er
  -- iemand met tien dollar aanschuift.
  v_koop := greatest(100, least(500, coalesce(p_buyin, 200)));

  select p.balance, p.username into v_saldo, v_naam
    from public.profiles p where p.id = v_uid for update;
  if v_saldo is null then raise exception 'no profile'; end if;
  if v_saldo < v_koop then raise exception 'not enough money'; end if;

  if v_zat is not null then
    -- Bijkopen: dezelfde stoel, alleen fiches erbij. Zo verschuift niemand aan tafel en
    -- houdt de knop zijn plek.
    update public.profiles set balance = balance - v_koop where id = v_uid;
    update public.pk_players set stack = v_koop
     where lobby_id = v_lobby and user_id = v_uid
    returning seat_no into v_stoel;
  else
    -- De laagste vrije stoel.
    -- Geen coalesce: min() over niets is null, en dat is precies hoe je weet dat de tafel
    -- vol zit. Met een coalesce naar nul werd de zevende speler op stoel nul gezet.
    select min(x) into v_stoel
      from generate_series(0, 5) x
     where not exists (select 1 from public.pk_players q
                        where q.lobby_id = v_lobby and q.seat_no = x);
    if v_stoel is null then raise exception 'table is full'; end if;

    update public.profiles set balance = balance - v_koop where id = v_uid;
    insert into public.pk_players (lobby_id, user_id, username, seat_no, stack)
         values (v_lobby, v_uid, v_naam, v_stoel, v_koop);
  end if;

  -- In het grootboek, zodat na te rekenen is wat poker met je saldo heeft gedaan. Zie
  -- sql/poker_ledger.sql; zonder dat bestand slaat dit stil over.
  if to_regprocedure('poker.note(uuid, text, bigint, text, integer)') is not null then
    execute 'select poker.note($1, $2, $3, $4, $5)' using
      v_uid, v_naam, v_lobby, case when v_zat is null then 'sit' else 'rebuy' end, -v_koop;
  end if;

  return json_build_object('ok', true, 'seat', v_stoel, 'stack', v_koop,
                           'balance', v_saldo - v_koop);
end;
$$;

revoke all on function public.pk_sit(integer) from public, anon;
grant execute on function public.pk_sit(integer) to authenticated;

-- Zie je hieronder "DEEL 5 VAN 14 IS HELEMAAL GEDRAAID"? Dan is
-- dit deel compleet aangekomen en gelukt. Maak de editor leeg en ga door met deel 6.
select 'DEEL 5 VAN 14 IS HELEMAAL GEDRAAID' as klaar;
