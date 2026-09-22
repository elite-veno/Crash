# De SQL achter het casino

De pagina praat met Supabase (Postgres + PostgREST). Wat hier staat is wat daarin moet.
Draai het in de SQL-editor van Supabase, in deze volgorde. Alles is veilig om twee keer te
draaien.

| bestand | wat het doet |
|---|---|
| `sprint_reset.sql` | iedereen na elke sprint terug op $1000 |
| `poker.sql` | de tabellen en views van poker |
| `poker_rpc.sql` | de functies van poker: delen, inzetten, afrekenen |

**Er staat hier geen enkele sleutel in, en die hoort er ook niet in.** De pagina gebruikt
alleen de publieke sleutel; de `service_role`-sleutel hoort nergens anders dan in het
dashboard van Supabase.

## Zelf naspelen zonder Supabase

De functies zijn gewone Postgres, dus ze zijn na te spelen op een lege database. `test_stub.sql`
zet het kleinste stukje Supabase neer dat ervoor nodig is -- een profielentabel en een
`auth.uid()` die te sturen is -- zodat de tests hiernaast kunnen draaien.

```sh
# een Postgres in /tmp, als de gebruiker postgres want initdb wil niet als root
D=/tmp/pgpoker; PG=/usr/lib/postgresql/16/bin
rm -rf $D && mkdir -p $D/data $D/sock && chown -R postgres:postgres $D
su postgres -c "$PG/initdb -D $D/data -U postgres --auth=trust"
su postgres -c "$PG/pg_ctl -D $D/data -o '-k $D/sock -h \"\"' -l $D/log start"

# en dan alles erin
su postgres -c "psql -h $D/sock -U postgres -q \
  -f sql/test_stub.sql -f sql/sprint_reset.sql -f sql/poker.sql -f sql/poker_rpc.sql"

# de tests
su postgres -c "psql -h $D/sock -U postgres -q -f sql/sprint_reset_test.sql"
node tools/poker_sql_test.js 2000
```

`tools/poker_sql_test.js` is de belangrijkste van de twee: die legt de handbeoordelaar in
SQL naast die in `crash.html` en controleert dat ze op elke hand hetzelfde zeggen. Zeggen
ze iets anders, dan ziet een speler zichzelf winnen terwijl het geld naar een ander gaat.
