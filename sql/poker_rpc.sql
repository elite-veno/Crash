-- De functies van poker. Alles wat een speler kan doen loopt hier langs, en niets anders
-- raakt de tabellen aan. Draai dit ná sql/poker.sql.
--
-- Alle bedragen in centen, zodat er niets wegvalt in de afronding.

-- ---------- de handbeoordelaar ----------
-- Dezelfde regels als ODDS.pokerScore in crash.html, en getoetst met dezelfde gevallen:
-- zeven kaarten naar één getal waarmee twee handen tegen elkaar te leggen zijn. Een kaart
-- is 'As', 'Th', '2c' -- rang plus kleur, tien als T.
create or replace function public.pk_rank(c text)
returns int language sql immutable as $$
  select case left(c, 1)
    when 'A' then 14 when 'K' then 13 when 'Q' then 12 when 'J' then 11 when 'T' then 10
    else left(c, 1)::int end;
$$;

-- De hoogste straat in een rij rangen, of 0. Het aas telt aan beide kanten: als hoogste in
-- 10-J-Q-K-A en als laagste in A-2-3-4-5, en dan is de straat vijf-hoog.
create or replace function public.pk_straight(rangen int[])
returns int language plpgsql immutable as $$
declare
  heeft boolean[] := array_fill(false, array[15]);
  r int; hoog int; i int; alle boolean;
begin
  foreach r in array rangen loop
    heeft[r] := true;
    if r = 14 then heeft[1] := true; end if;
  end loop;
  for hoog in reverse 14..5 loop
    alle := true;
    for i in 0..4 loop
      if not heeft[hoog - i] then alle := false; exit; end if;
    end loop;
    if alle then return hoog; end if;
  end loop;
  return 0;
end;
$$;

-- Zeven kaarten naar één getal. Categorie maal 15^5, dan de tiebreakers.
create or replace function public.pk_score(kaarten text[])
returns bigint language plpgsql immutable as $$
declare
  rangen int[] := '{}';
  per_rang int[] := array_fill(0, array[15]);
  kleuren text[] := '{}';
  kleur_rangen int[] := '{}';
  k text; r int; i int; c int;
  groepen int[][];
  vier int := 0; drie int := 0; drie2 int := 0; paar1 int := 0; paar2 int := 0;
  sleutels int[] := '{0,0,0,0,0}';
  cat int := 0;
  sf int; st int;
  kickers int[] := '{}';
  waarde bigint := 0;
begin
  foreach k in array kaarten loop
    r := public.pk_rank(k);
    rangen := rangen || r;
    per_rang[r] := per_rang[r] + 1;
  end loop;

  -- Kleur: vijf of meer van één soort.
  foreach k in array kaarten loop
    if (select count(*) from unnest(kaarten) x where right(x, 1) = right(k, 1)) >= 5 then
      select array_agg(public.pk_rank(x) order by public.pk_rank(x) desc)
        into kleur_rangen from unnest(kaarten) x where right(x, 1) = right(k, 1);
      exit;
    end if;
  end loop;

  if array_length(kleur_rangen, 1) is not null then
    sf := public.pk_straight(kleur_rangen);
    if sf > 0 then
      cat := 8; sleutels := array[sf, 0, 0, 0, 0];
      waarde := cat;
      foreach i in array sleutels loop waarde := waarde * 15 + i; end loop;
      return waarde;
    end if;
  end if;

  -- De rangen op aantal, hoog eerst.
  for r in reverse 14..2 loop
    c := per_rang[r];
    if c = 4 then vier := r;
    elsif c = 3 then
      if drie = 0 then drie := r; else drie2 := r; end if;
    elsif c = 2 then
      if paar1 = 0 then paar1 := r; elsif paar2 = 0 then paar2 := r; end if;
    end if;
  end loop;

  if vier > 0 then
    select coalesce(max(x), 0) into i from unnest(rangen) x where x <> vier;
    cat := 7; sleutels := array[vier, i, 0, 0, 0];
  elsif drie > 0 and (drie2 > 0 or paar1 > 0) then
    cat := 6; sleutels := array[drie, greatest(drie2, paar1), 0, 0, 0];
  elsif array_length(kleur_rangen, 1) is not null then
    cat := 5;
    sleutels := array[kleur_rangen[1], kleur_rangen[2], kleur_rangen[3],
                      kleur_rangen[4], kleur_rangen[5]];
  else
    st := public.pk_straight(rangen);
    if st > 0 then
      cat := 4; sleutels := array[st, 0, 0, 0, 0];
    elsif drie > 0 then
      select array_agg(x order by x desc) into kickers
        from (select distinct unnest(rangen) x) q where x <> drie;
      cat := 3; sleutels := array[drie, coalesce(kickers[1], 0), coalesce(kickers[2], 0), 0, 0];
    elsif paar1 > 0 and paar2 > 0 then
      -- Drie paren kan met zeven kaarten: de twee hoogste tellen, en de hoogste kaart van
      -- de rest -- ook als dat de kaart van het derde paar is -- wordt de kicker.
      select coalesce(max(x), 0) into i from unnest(rangen) x where x <> paar1 and x <> paar2;
      cat := 2; sleutels := array[paar1, paar2, i, 0, 0];
    elsif paar1 > 0 then
      select array_agg(x order by x desc) into kickers
        from (select distinct unnest(rangen) x) q where x <> paar1;
      cat := 1; sleutels := array[paar1, coalesce(kickers[1], 0), coalesce(kickers[2], 0),
                                 coalesce(kickers[3], 0), 0];
    else
      select array_agg(x order by x desc) into kickers from (select distinct unnest(rangen) x) q;
      cat := 0; sleutels := array[kickers[1], kickers[2], kickers[3], kickers[4], kickers[5]];
    end if;
  end if;

  waarde := cat;
  foreach i in array sleutels loop waarde := waarde * 15 + coalesce(i, 0); end loop;
  return waarde;
end;
$$;

-- ---------- eerlijk delen ----------
-- De stok ligt vast voordat er gedeeld wordt. De hash gaat vooraf naar de spelers, het
-- zaadje pas als de hand is afgerekend -- dan kan iedereen naspelen dat er onderweg niet
-- is geschud. Dezelfde afspraak als bij crash en blackjack.
create or replace function poker.fresh_deck()
returns text[] language sql immutable set search_path = '' as $$
  select array_agg(r.v || s.v order by s.i, r.i)
    from unnest(array['s','h','d','c']) with ordinality as s(v, i),
         unnest(array['2','3','4','5','6','7','8','9','T','J','Q','K','A']) with ordinality as r(v, i);
$$;

-- pgcrypto staat op Supabase in het schema `extensions` en op een kale Postgres meestal in
-- `public`. De functies hieronder draaien met `search_path = ''` -- dat hoort zo, want een
-- definer-functie met een te kapen zoekpad voert iets anders uit dan je denkt -- en dan
-- moet elke naam volledig gekwalificeerd zijn. Dus wordt hier één keer opgezocht waar
-- `digest` staat, en daar wijst poker.sha256 naar.
do $$
declare v_schema text;
begin
  select n.nspname into v_schema
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where p.proname = 'digest' and pg_get_function_identity_arguments(p.oid) = 'text, text'
   limit 1;
  if v_schema is null then
    raise exception 'pgcrypto is niet geinstalleerd: create extension pgcrypto;';
  end if;
  execute format($f$
    create or replace function poker.sha256(p text)
    returns bytea language sql immutable set search_path = '' as
    $b$ select %I.digest(p, 'sha256') $b$;
  $f$, v_schema);
end $$;

-- Fisher-Yates, gestuurd door het zaadje. Zelfde zaadje, zelfde stok.
create or replace function poker.shuffle(p_seed text)
returns text[] language plpgsql immutable set search_path = '' as $$
declare
  kaarten text[] := poker.fresh_deck();
  n int := array_length(kaarten, 1);
  i int; j int; tmp text; h bytea;
begin
  for i in reverse n..2 loop
    -- Voor elke stap een eigen hash van zaadje plus positie: zo hangt elke trekking aan
    -- het zaadje en is de hele stok uit dat ene getal na te rekenen.
    h := poker.sha256(p_seed || ':' || i::text);
    j := 1 + (('x' || encode(substring(h from 1 for 4), 'hex'))::bit(32)::bigint
              & 2147483647) % i;
    tmp := kaarten[i]; kaarten[i] := kaarten[j]; kaarten[j] := tmp;
  end loop;
  return kaarten;
end;
$$;

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

  select l.lobby_id into v_lobby from public.my_lobby l limit 1;
  if v_lobby is null then raise exception 'join a table first'; end if;

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

-- ---------- opstaan ----------
create or replace function public.pk_leave()
returns json language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := auth.uid();
  v_lobby bigint;
  v_stack integer;
  v_ronde bigint;
begin
  if v_uid is null then raise exception 'not signed in'; end if;

  select p.lobby_id, p.stack into v_lobby, v_stack
    from public.pk_players p where p.user_id = v_uid for update;
  if v_lobby is null then return json_build_object('ok', true, 'stack', 0); end if;

  -- Zit je midden in een hand, dan pas je eerst. Je inzet blijft in de pot staan -- dat is
  -- geld dat je al hebt ingelegd, en weglopen mag dat niet ongedaan maken.
  select r.id into v_ronde from public.pk_rounds r
    where r.lobby_id = v_lobby and r.settled_at is null order by r.id desc limit 1;
  if v_ronde is not null then
    -- En dit is de stapel die telt. `pk_players.stack` wordt alleen bij het delen en bij
    -- het afrekenen bijgewerkt; tijdens een hand staat daar nog de stand van VOOR je
    -- inzetten. Wie daarmee uitbetaalt, geeft alles terug wat er al in de pot ligt --
    -- geld uit het niets, en te herhalen zo vaak je wilt.
    update public.pk_seats s set folded = true, acted = true
     where s.round_id = v_ronde and s.user_id = v_uid and not s.folded;
    select s.stack into v_stack from public.pk_seats s
      where s.round_id = v_ronde and s.user_id = v_uid;
    -- De stoel in de hand houdt geen fiches meer vast: die zijn nu van het saldo.
    update public.pk_seats s set stack = 0
      where s.round_id = v_ronde and s.user_id = v_uid;
  end if;

  -- Alleen de stoel aan DEZE tafel. Zonder dat filter haalt opstaan je overal weg terwijl
  -- er maar één stapel wordt uitbetaald.
  delete from public.pk_players where user_id = v_uid and lobby_id = v_lobby;
  update public.profiles set balance = balance + coalesce(v_stack, 0) where id = v_uid;

  if to_regprocedure('poker.note(uuid, text, bigint, text, integer)') is not null then
    execute 'select poker.note($1, $2, $3, $4, $5)' using
      v_uid, (select username from public.profiles where id = v_uid), v_lobby, 'leave', v_stack;
  end if;

  return json_build_object('ok', true, 'stack', v_stack);
end;
$$;

revoke all on function public.pk_leave() from public, anon;
grant execute on function public.pk_leave() to authenticated;

-- ---------- een zet doen ----------
-- Dit is de grendel. De browser stuurt één getal in het hele spel: het totaal waar je deze
-- straat naartoe verhoogt. Dat getal zit aan twee kanten vast in de stand op de server, en
-- alles eromheen -- of je aan de beurt bent, of je al gezet hebt, wat je nog hebt -- komt
-- uit de tabellen en niet uit wat de browser beweert.
--
-- `p_seq` is het volgnummer van de zet die de speler dénkt te doen. Stuurt een tweede tab
-- dezelfde zet nog een keer, dan klopt dat nummer niet meer en gebeurt er niets.
create or replace function public.pk_act(p_round bigint, p_seq integer, p_move text, p_to integer default null)
returns json language plpgsql security definer set search_path = '' as $$
declare
  v_uid uuid := auth.uid();
  r public.pk_rounds%rowtype;
  s public.pk_seats%rowtype;
  v_tegaan integer;
  v_doel integer;
  v_bij integer;
  v_vol boolean;
begin
  if v_uid is null then raise exception 'not signed in'; end if;

  select * into r from public.pk_rounds where id = p_round for update;
  if r.id is null then raise exception 'no such hand'; end if;
  if r.settled_at is not null then raise exception 'hand is over'; end if;
  if r.act_seq <> p_seq then raise exception 'too late'; end if;

  select * into s from public.pk_seats
   where round_id = p_round and user_id = v_uid for update;
  if s.round_id is null then raise exception 'not in this hand'; end if;
  if r.to_act_seat is distinct from s.seat_no then raise exception 'not your turn'; end if;
  if s.folded or s.allin then raise exception 'you are out of this hand'; end if;

  v_tegaan := greatest(0, r.high_bet - s.bet);

  if p_move = 'fold' then
    update public.pk_seats set folded = true, acted = true
     where round_id = p_round and seat_no = s.seat_no;

  elsif p_move = 'check' then
    if v_tegaan > 0 then raise exception 'cannot check'; end if;
    update public.pk_seats set acted = true
     where round_id = p_round and seat_no = s.seat_no;

  elsif p_move = 'call' then
    if v_tegaan <= 0 then raise exception 'nothing to call'; end if;
    v_bij := least(v_tegaan, s.stack);
    update public.pk_seats
       set stack = stack - v_bij, bet = bet + v_bij, total_bet = total_bet + v_bij,
           acted = true, allin = (stack - v_bij) = 0
     where round_id = p_round and seat_no = s.seat_no;

  elsif p_move = 'raise' then
    if not s.may_raise then raise exception 'cannot raise again'; end if;
    v_doel := coalesce(p_to, 0);
    if v_doel > s.bet + s.stack then raise exception 'more than you have'; end if;
    if v_doel <= r.high_bet then raise exception 'raise too small'; end if;
    -- Onder het minimum mag alleen als het alles is wat je hebt.
    if v_doel < r.high_bet + r.min_raise and v_doel <> s.bet + s.stack then
      raise exception 'raise too small';
    end if;
    v_bij := v_doel - s.bet;
    v_vol := (v_doel - r.high_bet) >= r.min_raise;

    update public.pk_seats
       set stack = stack - v_bij, bet = v_doel, total_bet = total_bet + v_bij,
           acted = true, allin = (stack - v_bij) = 0
     where round_id = p_round and seat_no = s.seat_no;

    if v_vol then
      -- Een volle verhoging heropent de ronde: iedereen mag weer reageren en weer verhogen.
      update public.pk_rounds set min_raise = v_doel - r.high_bet, high_bet = v_doel
       where id = p_round;
      update public.pk_seats set acted = false, may_raise = true
       where round_id = p_round and seat_no <> s.seat_no and not folded and not allin;
    else
      -- Een korte all-in verhoogt de inzet wel, maar wie al gezet had mag alleen nog het
      -- verschil bijleggen -- niet opnieuw verhogen op een minimum dat hierop gebouwd is.
      --
      -- In ÉÉN opdracht, en dat is geen stijlkeuze. Er stonden hier twee updates: eerst
      -- `acted = false` voor iedereen, daarna `may_raise = false where ... and acted`.
      -- Maar `acted` was op dat moment net op false gezet, dus die tweede raakte niemand
      -- en heropende de korte all-in het bieden alsnog -- precies wat hij moest voorkomen.
      update public.pk_rounds set high_bet = v_doel where id = p_round;
      update public.pk_seats
         set may_raise = not acted,   -- wie nog niet gezet had mag straks gewoon verhogen
             acted = false
       where round_id = p_round and seat_no <> s.seat_no and not folded and not allin;
    end if;

  else
    raise exception 'unknown move';
  end if;

  update public.pk_rounds set act_seq = act_seq + 1 where id = p_round;
  perform public.pk_advance(p_round);
  return json_build_object('ok', true);
end;
$$;

revoke all on function public.pk_act(bigint, integer, text, integer) from public, anon;
grant execute on function public.pk_act(bigint, integer, text, integer) to authenticated;

-- ---------- de hand vooruit ----------
-- Wie is er hierna? De eerste die nog kan en nog moet: niet gepast, niet all-in, en of nog
-- niet gezet of nog niet op de hoogste inzet.
create or replace function public.pk_next_seat(p_round bigint, p_vanaf smallint)
returns smallint language plpgsql security definer set search_path = '' as $$
declare
  r public.pk_rounds%rowtype;
  d int; i smallint; s public.pk_seats%rowtype;
  n int;
begin
  select * into r from public.pk_rounds where id = p_round;
  select count(*) into n from public.pk_seats where round_id = p_round;
  for d in 1..n loop
    i := ((p_vanaf + d) % n)::smallint;
    select * into s from public.pk_seats where round_id = p_round and seat_no = i;
    if s.seat_no is null or s.folded or s.allin or s.stack <= 0 then continue; end if;
    if not s.acted or s.bet <> r.high_bet then return i; end if;
  end loop;
  return null;
end;
$$;

-- De hand een stap verder: volgende speler, volgende straat, of afrekenen.
create or replace function public.pk_advance(p_round bigint)
returns void language plpgsql security definer set search_path = '' as $$
declare
  r public.pk_rounds%rowtype;
  v_levend int;
  v_kunnen int;
  v_volgende smallint;
  v_kaarten text[];
  v_gedeeld int;
begin
  select * into r from public.pk_rounds where id = p_round for update;
  if r.settled_at is not null then return; end if;

  select count(*) into v_levend from public.pk_seats where round_id = p_round and not folded;
  -- Iedereen op één na gepast: die krijgt de pot, zonder te hoeven laten zien.
  if v_levend <= 1 then
    perform public.pk_settle(p_round);
    return;
  end if;

  v_volgende := public.pk_next_seat(p_round, coalesce(r.to_act_seat, r.button_seat));
  if v_volgende is not null then
    update public.pk_rounds
       set to_act_seat = v_volgende, act_deadline = now() + interval '25 seconds'
     where id = p_round;
    return;
  end if;

  -- De straat is dicht. Inzetten van deze straat gaan in de pot (total_bet houdt ze bij),
  -- en dan de volgende kaarten.
  update public.pk_seats set bet = 0, acted = false, may_raise = true
   where round_id = p_round;
  update public.pk_rounds set high_bet = 0, min_raise = bb where id = p_round;

  if r.street >= 3 then
    perform public.pk_settle(p_round);
    return;
  end if;

  select d.cards into v_kaarten from poker.deck d where d.round_id = p_round;
  -- De eerste kaarten van de stok zijn voor de spelers: twee per stoel.
  select count(*) * 2 into v_gedeeld from public.pk_seats where round_id = p_round;

  update public.pk_rounds
     set street = r.street + 1,
         board = case r.street
                   when 0 then v_kaarten[v_gedeeld + 1 : v_gedeeld + 3]
                   when 1 then r.board || v_kaarten[v_gedeeld + 4]
                   else r.board || v_kaarten[v_gedeeld + 5]
                 end
   where id = p_round;

  -- Is er hooguit één speler die nog fiches heeft om mee te zetten, dan valt er niets meer
  -- te bieden: het bord loopt uit en de hand gaat naar de showdown. pk_settle legt de rest
  -- van de kaarten zelf neer.
  --
  -- Deze controle stond eerst ONDER het bepalen van de volgende speler, en dan wacht de
  -- tafel op iemand die niets meer kan doen.
  select count(*) into v_kunnen from public.pk_seats
   where round_id = p_round and not folded and not allin and stack > 0;
  if v_kunnen <= 1 then
    perform public.pk_settle(p_round);
    return;
  end if;

  update public.pk_rounds
     set to_act_seat = public.pk_next_seat(p_round, r.button_seat),
         act_deadline = now() + interval '25 seconds'
   where id = p_round;
end;
$$;

-- ---------- afrekenen ----------
-- De pot verdelen, met zijpotten. Dezelfde rekensom als ODDS.pokerPots in crash.html:
-- iedereen speelt alleen om het geld dat hij zelf heeft kunnen matchen.
create or replace function public.pk_settle(p_round bigint)
returns void language plpgsql security definer set search_path = '' as $$
declare
  r public.pk_rounds%rowtype;
  v_niveau int;
  v_vorig int := 0;
  v_pot int;
  v_beste bigint;
  v_winnaars smallint[];
  v_ieder int;
  v_rest int;
  v_board text[];
  v_kaarten text[];
  w smallint;
  v_eerste smallint;
  v_n int;
begin
  select * into r from public.pk_rounds where id = p_round for update;
  if r.settled_at is not null then return; end if;

  select count(*) into v_n from public.pk_seats where round_id = p_round;
  v_board := r.board;

  -- De rest van het bord moet er liggen voordat er vergeleken wordt: als iedereen all-in
  -- ging op de flop, komen turn en river er alsnog.
  select d.cards into v_kaarten from poker.deck d where d.round_id = p_round;
  if (select count(*) from public.pk_seats where round_id = p_round and not folded) > 1 then
    while array_length(v_board, 1) is null or array_length(v_board, 1) < 5 loop
      v_board := coalesce(v_board, '{}'::text[]) ||
                 v_kaarten[v_n * 2 + coalesce(array_length(v_board, 1), 0) + 1];
    end loop;
  end if;

  -- De kaarten van wie nog meedoet gaan open, en krijgen hun score.
  update public.pk_seats s
     set shown = true,
         hole = (select h.cards from poker.hole h
                  where h.round_id = p_round and h.seat_no = s.seat_no)
   where s.round_id = p_round and not s.folded
     and (select count(*) from public.pk_seats q where q.round_id = p_round and not q.folded) > 1;

  -- Elk verschillend inzetbedrag is een laag.
  v_eerste := ((r.button_seat + 1) % v_n)::smallint;
  for v_niveau in
    select distinct total_bet from public.pk_seats
     where round_id = p_round and total_bet > 0 order by 1
  loop
    select sum(least(total_bet, v_niveau) - least(total_bet, v_vorig)) into v_pot
      from public.pk_seats where round_id = p_round;

    if v_pot > 0 then
      select max(public.pk_score(
               (select h.cards from poker.hole h
                 where h.round_id = p_round and h.seat_no = s.seat_no) || v_board))
        into v_beste
        from public.pk_seats s
       where s.round_id = p_round and not s.folded and s.total_bet >= v_niveau;

      if v_beste is null then
        -- Iedereen die om deze laag speelde is gepast. Dan gaat hij terug naar wie hem
        -- volstortte, NAAR RATO -- niet in zijn geheel naar de grootste inlegger. Dat
        -- laatste stond er, en dan kreeg één speler geld terug dat van een ander was.
        update public.pk_seats s
           set payout = s.payout
                      + (least(s.total_bet, v_niveau) - least(s.total_bet, v_vorig))
         where s.round_id = p_round;
      else
        select array_agg(s.seat_no order by ((s.seat_no - v_eerste + v_n) % v_n))
          into v_winnaars
          from public.pk_seats s
         where s.round_id = p_round and not s.folded and s.total_bet >= v_niveau
           and public.pk_score(
                 (select h.cards from poker.hole h
                   where h.round_id = p_round and h.seat_no = s.seat_no) || v_board) = v_beste;

        v_ieder := v_pot / array_length(v_winnaars, 1);
        v_rest := v_pot - v_ieder * array_length(v_winnaars, 1);
        -- De oneven fiches gaan naar links van de knop, zoals aan een echte tafel.
        foreach w in array v_winnaars loop
          update public.pk_seats
             set payout = payout + v_ieder + (case when v_rest > 0 then 1 else 0 end)
           where round_id = p_round and seat_no = w;
          if v_rest > 0 then v_rest := v_rest - 1; end if;
        end loop;
      end if;
    end if;
    v_vorig := v_niveau;
  end loop;

  -- De uitbetaling gaat naar de stapel, niet naar het saldo: je blijft aan tafel zitten.
  --
  -- Let op wat hier de waarheid is. `pk_seats.stack` is wat er ná deze hand nog voor je
  -- ligt: daar zijn de blinds, de calls en de verhogingen al van af. `pk_players.stack`
  -- stond nog op de stand van vóór de hand. Er stond hier eerst `pk_players.stack + payout`
  -- en dat maakte fiches: alles wat je tijdens de hand had ingelegd kwam er zo weer bij.
  update public.pk_players pl
     set stack = s.stack + s.payout
    from public.pk_seats s
   where s.round_id = p_round and s.user_id = pl.user_id;

  update public.pk_rounds
     set settled_at = now(), street = 5, to_act_seat = null, act_deadline = null, board = v_board
   where id = p_round;
end;
$$;

revoke all on function public.pk_advance(bigint) from public, anon, authenticated;
revoke all on function public.pk_settle(bigint) from public, anon, authenticated;
revoke all on function public.pk_next_seat(bigint, smallint) from public, anon, authenticated;

-- ---------- de klok ----------
-- Elke browser mag dit porren: wie als eerste merkt dat er gedeeld of afgerekend moet
-- worden, vraagt het aan, en de server doet het één keer. Er zit geen controle op of de
-- aanroeper aan tafel zit, met opzet -- anders kan een vastgelopen tafel door niemand meer
-- losgemaakt worden. Er valt ook niets mee te winnen: alles wat hier gebeurt hangt aan
-- now() en aan de stand, niet aan wie het vraagt.
create or replace function public.pk_tick(p_lobby bigint)
returns json language plpgsql security definer set search_path = '' as $$
declare
  r public.pk_rounds%rowtype;
  v_spelers int;
  v_zaad text;
  v_commit text;
  v_kaarten text[];
  v_ronde bigint;
  v_knop smallint;
  v_i int := 0;
  p record;
  v_sb smallint; v_bb smallint;
  v_zout text;
  w record;
begin
  -- Eén tafel tegelijk. Twee browsers die op hetzelfde moment porren zagen allebei geen
  -- lopende hand en deelden er allebei een; op de tijdklok sloegen ze samen een beurt over.
  -- Dit slot geldt tot het einde van de transactie, dus alle porren voor één tafel staan
  -- netjes in de rij.
  perform pg_advisory_xact_lock(p_lobby);

  select * into r from public.pk_rounds
   where lobby_id = p_lobby and settled_at is null order by id desc limit 1 for update;

  -- Loopt er een hand? Dan alleen kijken of iemand te lang nadenkt.
  if r.id is not null then
    if r.act_deadline is not null and now() > r.act_deadline and r.to_act_seat is not null then
      -- Wie zijn tijd laat verlopen checkt als dat gratis is, en past anders. Zo blijft een
      -- tafel niet staan omdat iemand zijn tab dichtgooit, en verliest niemand zijn inzet
      -- door een haperende verbinding als er niets te betalen viel.
      if (select s.bet from public.pk_seats s
           where s.round_id = r.id and s.seat_no = r.to_act_seat) = r.high_bet then
        update public.pk_seats set acted = true
         where round_id = r.id and seat_no = r.to_act_seat;
      else
        update public.pk_seats set folded = true, acted = true
         where round_id = r.id and seat_no = r.to_act_seat;
      end if;
      update public.pk_rounds set act_seq = act_seq + 1 where id = r.id;
      perform public.pk_advance(r.id);
    end if;
    return json_build_object('ok', true, 'round', r.id);
  end if;

  -- Geen hand. Eerst opruimen: wie de lobby heeft verlaten zonder op te staan, laat een
  -- rij achter aan een tafel waar hij niet meer bij hoort, met zijn fiches erop. De pagina
  -- staat nu eerst op voordat ze weggaat, maar een dichtgeslagen tab doet dat niet.
  --
  -- Dit staat met opzet tussen de handen door: midden in een hand iemand van tafel halen
  -- zou de pot scheef trekken. En het hele blok is afgeschermd -- vindt het de ledentabel
  -- niet, of ziet die er anders uit dan hier verwacht, dan slaat het over. Een tafel die
  -- vastloopt omdat het opruimen struikelt is erger dan een rij die blijft staan.
  begin
    if (select count(*) from information_schema.columns
         where table_schema = 'public' and table_name = 'lobby_members'
           and column_name in ('lobby_id', 'user_id')) = 2 then
      for w in
        -- En één grendel erbij: alleen opruimen als er voor DEZE lobby uberhaupt leden
        -- in die tabel staan. Staat hij leeg, dan wordt het lidmaatschap ergens anders
        -- bijgehouden en betekent "staat er niet in" niet "hoort er niet bij" -- dan zou
        -- dit de hele tafel leegvegen in plaats van één achterblijver.
        execute 'select pl.user_id, pl.stack from public.pk_players pl'
             || ' where pl.lobby_id = $1'
             || '   and exists (select 1 from public.lobby_members m2'
             || '                where m2.lobby_id = pl.lobby_id)'
             || '   and not exists ('
             || '   select 1 from public.lobby_members m'
             || '    where m.lobby_id = pl.lobby_id and m.user_id = pl.user_id)'
        using p_lobby
      loop
        update public.profiles set balance = balance + w.stack where id = w.user_id;
        delete from public.pk_players pl
         where pl.lobby_id = p_lobby and pl.user_id = w.user_id;
      end loop;
    end if;
  exception when others then null;
  end;

  -- Kan er een hand beginnen? Wie geen fiches meer heeft doet niet mee.
  select count(*) into v_spelers from public.pk_players
   where lobby_id = p_lobby and stack > 0;
  if v_spelers < 2 then return json_build_object('ok', true, 'round', null); end if;

  -- De knop schuift een stoel op ten opzichte van de VORIGE hand -- niet ten opzichte van
  -- de hoogste die er ooit was. Met een max blijft hij hangen zodra hij één keer op de
  -- laatste stoel heeft gestaan, en dan post dezelfde speler elke hand de blind.
  select coalesce((select button_seat from public.pk_rounds
                    where lobby_id = p_lobby order by id desc limit 1), -1)
    into v_knop;

  v_zaad := encode(poker.sha256(gen_random_uuid()::text || clock_timestamp()::text), 'hex');
  v_commit := encode(poker.sha256('commit:' || v_zaad), 'hex');
  v_kaarten := poker.shuffle(v_zaad);

  select coalesce(max(sb), 5), coalesce(max(bb), 10) into v_sb, v_bb
    from public.pk_rounds where lobby_id = p_lobby;

  insert into public.pk_rounds (lobby_id, deck_commit, button_seat, sb, bb, min_raise, street)
       values (p_lobby, v_commit, ((v_knop + 1) % greatest(v_spelers, 2))::smallint,
               v_sb, v_bb, v_bb, 0)
    returning id into v_ronde;

  insert into poker.deck (round_id, seed, cards) values (v_ronde, v_zaad, v_kaarten);

  -- De stoelen, op volgorde, met hun kaarten. De kaarten gaan naar het andere schema; wat
  -- hier blijft staan is een gezouten hash, zodat elke speler zijn eigen hand meteen kan
  -- narekenen zonder dat iemand anders iets te zien krijgt.
  for p in select * from public.pk_players
            where lobby_id = p_lobby and stack > 0 order by seat_no loop
    v_zout := encode(poker.sha256(v_zaad || ':zout:' || v_i::text), 'hex');
    insert into public.pk_seats (round_id, seat_no, user_id, username, stack, card_commit)
         values (v_ronde, v_i::smallint, p.user_id, p.username, p.stack,
                 encode(poker.sha256(v_zout || ':' ||
                        v_kaarten[v_i * 2 + 1] || v_kaarten[v_i * 2 + 2]), 'hex'));
    insert into poker.hole (round_id, seat_no, player, cards, salt)
         values (v_ronde, v_i::smallint, p.user_id,
                 array[v_kaarten[v_i * 2 + 1], v_kaarten[v_i * 2 + 2]], v_zout);
    v_i := v_i + 1;
  end loop;

  -- De blinds. Heads-up post de knop de kleine blind; met meer spelers de stoel erna.
  declare
    v_n int := v_i;
    v_knop2 smallint;
    v_sbs smallint; v_bbs smallint;
  begin
    select button_seat into v_knop2 from public.pk_rounds where id = v_ronde;
    if v_n = 2 then
      v_sbs := v_knop2;
      v_bbs := ((v_knop2 + 1) % v_n)::smallint;
    else
      v_sbs := ((v_knop2 + 1) % v_n)::smallint;
      v_bbs := ((v_knop2 + 2) % v_n)::smallint;
    end if;

    update public.pk_seats
       set bet = least(v_sb, stack), total_bet = least(v_sb, stack),
           stack = stack - least(v_sb, stack), allin = stack <= v_sb
     where round_id = v_ronde and seat_no = v_sbs;
    update public.pk_seats
       set bet = least(v_bb, stack), total_bet = least(v_bb, stack),
           stack = stack - least(v_bb, stack), allin = stack <= v_bb
     where round_id = v_ronde and seat_no = v_bbs;

    update public.pk_rounds
       set high_bet = v_bb,
           to_act_seat = ((v_bbs + 1) % v_n)::smallint,
           act_deadline = now() + interval '25 seconds'
     where id = v_ronde;
  end;

  -- De stapels aan tafel volgen die in de hand.
  update public.pk_players pl set stack = s.stack
    from public.pk_seats s
   where s.round_id = v_ronde and s.user_id = pl.user_id;

  return json_build_object('ok', true, 'round', v_ronde, 'dealt', true);
end;
$$;

revoke all on function public.pk_tick(bigint) from public, anon;
grant execute on function public.pk_tick(bigint) to authenticated;

-- ---------- en nog eens de sloten ----------
-- poker.sql doet `revoke all on all functions in schema poker`, maar dat draait VOORDAT
-- dit bestand poker.sha256, poker.fresh_deck en poker.shuffle aanmaakt. Die drie hielden
-- dus de standaard PUBLIC EXECUTE die Postgres aan elke nieuwe functie geeft.
--
-- Vandaag is er niets mee te doen: zonder USAGE op het schema `poker` komt een aanroep er
-- niet eens langs. Maar het is één `grant usage` van iemand die het schema ooit open zet
-- verwijderd van poker.shuffle(zaadje) -- en dat geeft het hele deck terug. Een slot dat
-- alleen houdt zolang een ander slot houdt, is geen slot. Dus hier nog een keer, nu de
-- functies bestaan.
revoke all on all functions in schema poker from public, anon, authenticated;
