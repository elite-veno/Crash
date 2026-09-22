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
