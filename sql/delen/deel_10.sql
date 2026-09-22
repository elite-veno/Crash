-- ============================================================================
--  DEEL 10 VAN 14
-- ============================================================================
--
--  Plak dit pas NA deel 9. Die volgorde doet ertoe: dit deel gebruikt
--  wat de delen ervoor hebben aangemaakt.
--
--  Gaat er iets mis, draai dan niet verder -- kijk eerst wat er fout ging. Alles is
--  veilig om opnieuw te draaien, dus een deel nog een keer plakken kan altijd.
--
--  Uit: sql/poker_rpc.sql
-- ============================================================================


revoke all on function public.pk_advance(bigint) from public, anon, authenticated;
revoke all on function public.pk_settle(bigint) from public, anon, authenticated;
revoke all on function public.pk_next_seat(bigint, smallint) from public, anon, authenticated;
