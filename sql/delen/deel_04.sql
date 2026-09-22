-- ============================================================================
--  DEEL 4 VAN 14
-- ============================================================================
--
--  EERST DE EDITOR LEEGMAKEN: klik op "+ New query", of Ctrl+A en Delete. Staat er
--  nog iets van een vorige poging in -- zeker een half afgebroken stuk -- dan loopt
--  alles daarna scheef en krijg je een "syntax error" op een plek die niets zegt.
--
--  Plak dit pas NA deel 3. Die volgorde doet ertoe: dit deel gebruikt
--  wat de delen ervoor hebben aangemaakt.
--  Onderaan hoort dan "DEEL 4 VAN 14 IS HELEMAAL GEDRAAID" te staan.
--
--  Gaat er iets mis, draai dan niet verder -- kijk eerst wat er fout ging. Alles is
--  veilig om opnieuw te draaien, dus een deel nog een keer plakken kan altijd.
--
--  Uit: sql/poker_rpc.sql
-- ============================================================================


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

-- Zie je hieronder "DEEL 4 VAN 14 IS HELEMAAL GEDRAAID"? Dan is
-- dit deel compleet aangekomen en gelukt. Maak de editor leeg en ga door met deel 5.
select 'DEEL 4 VAN 14 IS HELEMAAL GEDRAAID' as klaar;
