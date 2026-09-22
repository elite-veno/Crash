-- ============================================================================
--  DEEL 3 VAN 14
-- ============================================================================
--
--  Plak dit pas NA deel 2. Die volgorde doet ertoe: dit deel gebruikt
--  wat de delen ervoor hebben aangemaakt.
--
--  Gaat er iets mis, draai dan niet verder -- kijk eerst wat er fout ging. Alles is
--  veilig om opnieuw te draaien, dus een deel nog een keer plakken kan altijd.
--
--  Uit: sql/poker.sql, sql/poker_rpc.sql
-- ============================================================================


-- ---------- de sprintreset raakt ook de tafels ----------
-- Fiches die op een pokertafel liggen zitten niet in profiles.balance, dus een reset die
-- alleen dat saldo op 1000 zet, slaat ze over. Wie $50.000 op een tafel parkeert over de
-- sprintgrens heen, begint de nieuwe sprint met $50.000 in plaats van met $1000 -- precies
-- wat de reset moet voorkomen.
--
-- Daarom: bij het omslaan vervalt de lopende hand en gaat elke stapel van tafel. Het geld
-- dat terugkomt doet er niet toe, want het saldo gaat er meteen daarna toch op 1000; wat
-- ertoe doet is dat er geen fiches ACHTERBLIJVEN die de reset overleven.
create or replace function poker.void_all(p_uid uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_ronde bigint;
begin
  -- De lopende hand waar deze speler in zit, wordt AFGEBROKEN -- niet doodverklaard.
  --
  -- Er stond hier eerst alleen `settled_at = now()`. Dat leek genoeg, want het saldo van
  -- deze speler gaat zo meteen toch op 1000. Maar aan die tafel zitten anderen, en die
  -- hebben hun inzet al in de pot staan. Die pot werd dan nooit uitbetaald: de sprintgrens
  -- van één speler maakte het geld van zijn tafelgenoten zoek, en zij hebben niets met die
  -- omslag te maken.
  --
  -- Dus: iedereen krijgt eerst terug wat hij deze hand heeft ingelegd, en dan pas gaat de
  -- ronde dicht. Het is geen hand die is uitgespeeld, dus niemand wint hem.
  for v_ronde in
    select r.id from public.pk_rounds r
     where r.settled_at is null
       and exists (select 1 from public.pk_seats s
                    where s.round_id = r.id and s.user_id = p_uid)
  loop
    update public.pk_seats s
       set stack = s.stack + s.total_bet, total_bet = 0, bet = 0
     where s.round_id = v_ronde;

    -- Op de lobby van DEZE ronde, niet op elke tafel waar deze speler toevallig zit.
    -- Zonder die grens overschreef een reset aan de ene tafel zijn stapel aan de andere.
    --
    -- En niet op een stoel die al verlaten is. Wie tijdens de hand is opgestaan heeft geen
    -- stapel aan tafel meer -- of een verse, als hij opnieuw is aangeschoven. Die
    -- overschrijven met wat er op de oude stoel lag, maakte zijn inkoop stuk.
    update public.pk_players pl set stack = s.stack
      from public.pk_seats s, public.pk_rounds rd
     where rd.id = v_ronde and s.round_id = v_ronde
       and s.user_id = pl.user_id and pl.lobby_id = rd.lobby_id
       and not s.left_table;

    -- Wie is opgestaan krijgt zijn inzet op zijn saldo. Hij zit niet meer aan tafel, dus
    -- de regel hierboven ziet hem niet -- en zonder dit was zijn inzet weg. Dezelfde tak
    -- als in pk_settle, en om dezelfde reden.
    --
    -- Behalve voor DEGENE om wie deze reset draait. Zijn saldo gaat zo meteen toch op
    -- 1000: bijschrijven heeft geen zin, en het kan niet eens -- deze functie draait dan
    -- binnen de trigger op precies die rij, en Postgres weigert een rij twee keer in
    -- dezelfde opdracht bij te werken. Zijn fiches zijn met de sprintgrens weg, en dat is
    -- ook de bedoeling: niemand neemt iets mee naar de nieuwe sprint.
    update public.profiles p
       set balance = p.balance + s.stack
      from public.pk_seats s
     where s.round_id = v_ronde and s.left_table and s.stack > 0
       and p.id = s.user_id and s.user_id <> p_uid;

    update public.pk_seats s set stack = 0
     where s.round_id = v_ronde and s.left_table;

    update public.pk_rounds
       set settled_at = now(), street = 5, to_act_seat = null, act_deadline = null
     where id = v_ronde;

    -- En het zaadje weg. Een afgebroken hand is nooit uitgespeeld, dus er valt niets na te
    -- rekenen -- maar de kaarten van iedereen aan die tafel zitten er wel in. Zolang de rij
    -- bestaat is er iets te lekken; verwijderd is er niets meer te lekken.
    delete from poker.deck d where d.round_id = v_ronde;
  end loop;

  -- En dan alleen deze speler van tafel. De rest blijft zitten met zijn fiches.
  delete from public.pk_players p where p.user_id = p_uid;
end;
$$;

revoke all on function poker.void_all(uuid) from public, anon, authenticated;
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
