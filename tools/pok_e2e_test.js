// Twee spelers, twee browsers, één pokertafel -- van inloggen tot opstaan, door de echte
// knoppen, tegen een nagebootste Supabase.
//
// Waarom deze toets er is: alle andere toetsen hiernaast kijken naar de database of naar
// het scherm, nooit naar het gesprek ertussen. Daardoor bleef een fout onzichtbaar die in
// productie elke poging om te gaan zitten liet klappen: pk_sit las my_lobby.lobby_id, en
// in de echte view heet die kolom `id`. De pagina las het wel goed, de database-toetsen
// draaiden tegen een nabouw met dezelfde verkeerde naam -- en zo was alles groen.
//
// Hoe het werkt: de pagina praat met BACKEND.url. Elk verzoek daarheen wordt hier
// onderschept en beantwoord uit een lokale Postgres, zoals PostgREST en GoTrue dat zouden
// doen: met de rol `authenticated`, met auth.uid() van de ingelogde speler, en met de
// rechten die Supabase standaard aan nieuwe tabellen en functies geeft. In die database
// staat sql/test_stub.sql -- met de lobby-tabellen, -view en -functies zoals ze in de
// echte Supabase staan -- en daarboven de vier bestanden uit sql/.
//
//   npm install playwright      (chromium staat al op /opt/pw-browsers)
//   node tools/pok_e2e_test.js
//
// Postgres: PGHOST (standaard /tmp/pgpoker/sock), gebruiker postgres, zonder wachtwoord.
const path = require('path');
const { execFile, execFileSync } = require('child_process');
const pad = process.env.PW_NODE_MODULES || path.join(__dirname, '..', 'node_modules');
const { chromium } = require(pad + '/playwright');
const BROWSER = process.env.PW_CHROMIUM || '/opt/pw-browsers/chromium-1194/chrome-linux/chrome';
const PSQL = process.env.PSQL || '/usr/lib/postgresql/16/bin/psql';
const PGHOST = process.env.PGHOST || '/tmp/pgpoker/sock';
const DB = 'pok_e2e';
const ROOT = path.join(__dirname, '..');
const PAGINA = 'file://' + path.join(ROOT, 'crash.html');

const SPELERS = {
  ann: { id: 'aaaaaaaa-0000-0000-0000-000000000001', wachtwoord: 'geheim1' },
  bob: { id: 'aaaaaaaa-0000-0000-0000-000000000002', wachtwoord: 'geheim2' },
};

// ---------- de database ----------
function psqlSync(args) {
  return execFileSync(PSQL, ['-X', '-q', '-h', PGHOST, '-U', 'postgres', ...args],
    { encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] });
}
function bouwDatabase() {
  psqlSync(['-d', 'postgres', '-c', 'drop database if exists ' + DB]);
  psqlSync(['-d', 'postgres', '-c', 'create database ' + DB]);
  // Wat Supabase standaard doet: anon en authenticated mogen bij alles wat er in `public`
  // wordt aangemaakt, tenzij het bestand het zelf weer intrekt. Dat moet VOOR de bestanden
  // staan -- poker.sql trekt het op pk_rounds en pk_seats juist in, en dat moet winnen.
  const voor = `
    create extension pgcrypto;
    do $$ begin create role anon; exception when duplicate_object then null; end $$;
    do $$ begin create role authenticated; exception when duplicate_object then null; end $$;
    grant usage on schema public to anon, authenticated;
    alter default privileges in schema public grant all on tables to anon, authenticated;
    alter default privileges in schema public grant all on functions to anon, authenticated;
    alter default privileges in schema public grant all on sequences to anon, authenticated;
    create schema if not exists auth;
    grant usage on schema auth to anon, authenticated;`;
  psqlSync(['-d', DB, '-v', 'ON_ERROR_STOP=1', '-c', voor]);
  for (const f of ['test_stub.sql', 'poker.sql', 'poker_rpc.sql', 'sprint_reset.sql', 'poker_ledger.sql']) {
    psqlSync(['-d', DB, '-v', 'ON_ERROR_STOP=1', '-f', path.join(ROOT, 'sql', f)]);
  }
  // De kolommen die de pagina naast het saldo op een profiel zet.
  const na = `
    grant execute on function auth.uid() to anon, authenticated;
    alter table public.profiles
      add column if not exists rounds int default 0, add column if not exists won numeric default 0,
      add column if not exists lost numeric default 0, add column if not exists profit numeric default 0,
      add column if not exists stats jsonb default '{}', add column if not exists achievements jsonb default '{}',
      add column if not exists ach_extra jsonb default '{}', add column if not exists featured jsonb default '[]',
      add column if not exists title text, add column if not exists last_seen timestamptz;
    delete from public.lobby_members; delete from public.lobbies;
    insert into public.profiles (id, username, balance) values
      ('${SPELERS.ann.id}', 'ann', 1000), ('${SPELERS.bob.id}', 'bob', 1000);`;
  psqlSync(['-d', DB, '-v', 'ON_ERROR_STOP=1', '-c', na]);
}

// Eén vraag, als een bepaalde speler. Geeft altijd precies één regel JSON terug.
function vraag(uid, sql) {
  const rol = uid ? 'authenticated' : 'anon';
  return new Promise((ok, fout) => {
    execFile(PSQL, ['-X', '-q', '-tA', '-h', PGHOST, '-U', 'postgres', '-d', DB, '-v', 'ON_ERROR_STOP=1',
      '-c', 'set role ' + rol,
      '-c', "select set_config('test.uid', '" + (uid || '') + "', false) is null",
      '-c', sql], { encoding: 'utf8' }, (e, stdout, stderr) => {
      if (e) {
        const m = /ERROR:\s+(.*)/.exec(stderr || '');
        return fout(new Error(m ? m[1] : (stderr || String(e))));
      }
      const regels = stdout.trim().split('\n');
      ok(regels[regels.length - 1]);
    });
  });
}
const naam = s => { if (!/^[a-z_][a-z0-9_]*$/.test(s)) throw new Error('rare naam: ' + s); return '"' + s + '"'; };
const letterlijk = v => v === null || v === undefined ? 'null'
  : "'" + String(typeof v === 'object' ? JSON.stringify(v) : v).replace(/'/g, "''") + "'";

// ---------- de nagebootste Supabase ----------
async function beantwoord(route) {
  const req = route.request();
  const url = new URL(req.url());
  const pad = url.pathname;
  const cors = { 'access-control-allow-origin': '*', 'access-control-allow-headers': '*',
                 'access-control-allow-methods': '*', 'content-type': 'application/json' };
  const antwoord = (status, data) => route.fulfill({ status, headers: cors,
    body: data === undefined ? '' : JSON.stringify(data) });
  if (req.method() === 'OPTIONS') return antwoord(204);
  let body = null;
  try { body = req.postData() ? JSON.parse(req.postData()) : null; } catch {}
  const token = (req.headers()['authorization'] || '').replace(/^Bearer /, '');
  const uid = /^tok-/.test(token) ? token.slice(4) : null;

  try {
    // -- inloggen (GoTrue) --
    if (pad === '/auth/v1/token') {
      const grant = url.searchParams.get('grant_type');
      let wie = null;
      if (grant === 'password') {
        const n = String(body.email || '').split('@')[0];
        if (SPELERS[n] && SPELERS[n].wachtwoord === body.password) wie = n;
      } else if (grant === 'refresh_token') {
        wie = Object.keys(SPELERS).find(n => 'ref-' + SPELERS[n].id === body.refresh_token);
      }
      if (!wie) return antwoord(400, { error_description: 'Invalid login credentials' });
      return antwoord(200, { access_token: 'tok-' + SPELERS[wie].id, refresh_token: 'ref-' + SPELERS[wie].id,
        user: { id: SPELERS[wie].id, user_metadata: { username: wie } } });
    }
    if (pad.startsWith('/auth/v1/')) return antwoord(200, {});

    // -- functies (PostgREST /rpc) --
    let m = /^\/rest\/v1\/rpc\/([a-z_][a-z0-9_]*)$/.exec(pad);
    if (m) {
      const args = Object.entries(body || {}).map(([k, v]) => naam(k) + ' => ' + letterlijk(v)).join(', ');
      const r = await vraag(uid, 'select coalesce(to_jsonb(public.' + naam(m[1]) + '(' + args + '))::text, \'null\')');
      return antwoord(200, JSON.parse(r));
    }

    // -- tabellen en views --
    m = /^\/rest\/v1\/([a-z_][a-z0-9_]*)$/.exec(pad);
    if (m) {
      const rel = 'public.' + naam(m[1]);
      const waar = [], orde = [];
      let limiet = '', kolommen = '*';
      for (const [k, v] of url.searchParams) {
        if (k === 'select') kolommen = v === '*' ? '*' : v.split(',').map(naam).join(', ');
        else if (k === 'order') for (const o of v.split(',')) {
          const [c, r] = o.split('.'); orde.push(naam(c) + (r === 'desc' ? ' desc' : ' asc'));
        }
        else if (k === 'limit') limiet = ' limit ' + Number(v);
        else if (k === 'on_conflict') {}
        else if (v.startsWith('eq.')) waar.push(naam(k) + '::text = ' + letterlijk(v.slice(3)));
        else throw new Error('filter niet nagebouwd: ' + k + '=' + v);
      }
      const w = waar.length ? ' where ' + waar.join(' and ') : '';
      const prefer = req.headers()['prefer'] || '';
      if (req.method() === 'GET') {
        const r = await vraag(uid, 'select coalesce(jsonb_agg(t)::text, \'[]\') from (select ' + kolommen +
          ' from ' + rel + w + (orde.length ? ' order by ' + orde.join(', ') : '') + limiet + ') t');
        return antwoord(200, JSON.parse(r));
      }
      if (req.method() === 'PATCH') {
        const zet = Object.entries(body).map(([k, v]) => naam(k) + ' = ' + letterlijk(v)).join(', ');
        const r = await vraag(uid, 'with t as (update ' + rel + ' set ' + zet + w +
          ' returning *) select coalesce(jsonb_agg(t)::text, \'[]\') from t');
        return /return=representation/.test(prefer) ? antwoord(200, JSON.parse(r)) : antwoord(204);
      }
      if (req.method() === 'POST') {
        const rijen = Array.isArray(body) ? body : [body];
        const cols = Object.keys(rijen[0]);
        const waarden = rijen.map(r => '(' + cols.map(c => letterlijk(r[c])).join(', ') + ')').join(', ');
        const merge = /merge-duplicates/.test(prefer)
          ? ' on conflict (id) do update set ' + cols.map(c => naam(c) + ' = excluded.' + naam(c)).join(', ')
          : '';
        const r = await vraag(uid, 'with t as (insert into ' + rel + ' (' + cols.map(naam).join(', ') +
          ') values ' + waarden + merge + ' returning *) select coalesce(jsonb_agg(t)::text, \'[]\') from t');
        return /return=representation/.test(prefer) ? antwoord(201, JSON.parse(r)) : antwoord(201);
      }
    }
    return antwoord(404, { message: 'niet nagebouwd: ' + req.method() + ' ' + pad });
  } catch (e) {
    // Zoals PostgREST: wat niet bestaat is een 404, al het andere een 400 met de melding
    // van de database. De pagina leest die melding en zet hem in beeld.
    const bestaatNiet = /does not exist|could not find/i.test(e.message);
    return antwoord(bestaatNiet ? 404 : 400, { message: e.message });
  }
}

// ---------- de spelers ----------
async function speler(browser, wie) {
  const ctx = await browser.newContext({ viewport: { width: 1280, height: 900 } });
  const p = await ctx.newPage();
  p.fouten = [];
  p.on('pageerror', e => p.fouten.push(e.message));
  await p.route('https://pqswfsvritbxrdtjtfrf.supabase.co/**', beantwoord);
  await p.goto(PAGINA);
  await p.fill('#authUser', wie);
  await p.fill('#authPass', SPELERS[wie].wachtwoord);
  await p.click('#authSubmit');
  // Na het inloggen herlaadt de pagina en begint ze met de opgeslagen sessie.
  await p.waitForFunction(() => typeof online === 'function' && online() && AUTH.profileAt,
    null, { timeout: 20000 });
  await p.evaluate(() => navigate('poker'));
  await p.waitForTimeout(800);
  return p;
}
const toast = p => p.evaluate(() => [...document.querySelectorAll('#pokerToasts .toast')]
  .map(t => t.textContent.trim()).join(' | '));
const db = sql => vraag(null, sql).catch(e => 'FOUT: ' + e.message);
const dbSU = sql => psqlSync(['-d', DB, '-tA', '-c', sql]).trim();

let mis = 0;
const check = (wat, ok, extra) => {
  if (!ok) mis++;
  console.log((ok ? 'ok    ' : 'FOUT  ') + wat + (extra ? '   (' + extra + ')' : ''));
};
async function wacht(voorwaarde, ms = 15000) {
  const t0 = Date.now();
  while (Date.now() - t0 < ms) { if (await voorwaarde()) return true; await new Promise(r => setTimeout(r, 250)); }
  return false;
}
const geld = () => Number(dbSU(`select (select sum(balance) from public.profiles)
  + coalesce((select sum(stack) from public.pk_players), 0)
  + coalesce((select sum(s.total_bet) from public.pk_seats s join public.pk_rounds r
               on r.id = s.round_id where r.settled_at is null), 0)`));

(async () => {
  bouwDatabase();
  const browser = await chromium.launch({ executablePath: BROWSER });
  try {
    // ---- 1. openbare tafel: gewoon op TAKE A SEAT drukken ----
    console.log('-- openbare tafel');
    const ann = await speler(browser, 'ann');
    check('ann is ingelogd en staat bij poker', await ann.evaluate(() => currentRoute === 'poker'));
    check('de knop zegt TAKE A SEAT en staat aan',
      await ann.evaluate(() => !$('pkSitBtn').disabled && $('pkSitBtn').textContent === 'TAKE A SEAT'));
    await ann.click('#pkSitBtn');
    const annZit = await wacht(async () => dbSU("select count(*) from public.pk_players where username='ann'") === '1');
    check('ann zit aan tafel na één klik', annZit, await toast(ann));
    check('en haar saldo is met de inkoop verlaagd', dbSU("select balance from public.profiles where username='ann'") === '800');

    const bob = await speler(browser, 'bob');
    await bob.click('#pkSitBtn');
    const bobZit = await wacht(async () => dbSU("select count(*) from public.pk_players where username='bob'") === '1');
    check('bob zit ook, na één klik', bobZit, await toast(bob));
    check('aan dezelfde tafel als ann',
      dbSU('select count(distinct lobby_id) from public.pk_players') === '1');

    // ---- 2. er wordt gedeeld en gespeeld ----
    const gedeeld = await wacht(async () => dbSU('select count(*) from public.pk_rounds where settled_at is null') === '1', 20000);
    check('de pagina porde de server en er is gedeeld', gedeeld);
    check('fiches kloppen tijdens de hand', geld() === 2000, 'totaal ' + geld());
    const aanDeBeurt = await wacht(async () =>
      (await ann.evaluate(() => !$('pkActions').hidden)) || (await bob.evaluate(() => !$('pkActions').hidden)), 15000);
    check('een van de twee krijgt de actieknoppen', aanDeBeurt);
    const wie = (await ann.evaluate(() => !$('pkActions').hidden)) ? ann : bob;
    check('en ziet zijn eigen twee kaarten', await wie.evaluate(() => POK.hole.length === 2));
    await wie.click('#pkFoldBtn');
    const om = await wacht(async () => dbSU('select count(*) from public.pk_rounds where settled_at is null') === '0'
      || dbSU('select count(*) from public.pk_rounds') === '2', 15000);
    check('passen rekent de hand af', om);
    check('fiches kloppen na de hand', geld() === 2000, 'totaal ' + geld());

    // ---- 3. opstaan ----
    await wacht(async () => ann.evaluate(() => !$('pkLeaveBtn').hidden && !$('pkLeaveBtn').disabled), 5000);
    await ann.click('#pkLeaveBtn');
    const weg = await wacht(async () => dbSU("select count(*) from public.pk_players where username='ann'") === '0');
    check('ann staat op', weg, await toast(ann));
    check('en haar fiches staan weer op haar saldo', geld() === 2000, 'totaal ' + geld());
    await bob.click('#pkLeaveBtn').catch(() => {});
    await wacht(async () => dbSU('select count(*) from public.pk_players') === '0');
    // Stonden ze allebei op midden in een hand, dan hoort die hand afgerekend te zijn: wie
    // als laatste overbleef won hem. Eerst bleef hij open staan, met de blinds in een pot
    // waar niemand meer bij kon -- de lege lobby werd opgeruimd en niemand porde hem nog.
    check('na het opstaan staat er aan de openbare tafel geen hand meer open',
      await wacht(async () => dbSU('select count(*) from public.pk_rounds where settled_at is null') === '0', 5000));
    check('en alle fiches staan weer op een saldo',
      dbSU('select sum(balance)::int from public.profiles') === '2000');

    // ---- 4. met een vriend: privétafel en code ----
    console.log('-- privétafel met een vriend');
    // Eerst allebei uit de openbare tafel.
    await ann.evaluate(() => lobbyLeave()); await bob.evaluate(() => lobbyLeave());
    await wacht(async () => dbSU('select count(*) from public.lobby_members') === '0');
    await ann.evaluate(() => lobbyRender());
    await ann.locator('#pokerLobbyBar button', { hasText: 'PRIVATE TABLE' }).click();
    const code = await wacht(async () => ann.evaluate(() => !!LOBBY.code)) && await ann.evaluate(() => LOBBY.code);
    check('ann opent een privétafel en krijgt een code', !!code, code);
    await bob.evaluate(() => lobbyRender());
    await bob.fill('#pokerLobbyBar input', code);
    await bob.locator('#pokerLobbyBar button', { hasText: 'JOIN' }).click();
    check('bob komt binnen met de code', await wacht(async () => bob.evaluate(c => LOBBY.code === c, code)));
    check('het is echt een privétafel', await bob.evaluate(() => LOBBY.private === true));
    await ann.click('#pkSitBtn'); await wacht(async () => dbSU("select count(*) from public.pk_players where username='ann'") === '1');
    await bob.click('#pkSitBtn'); await wacht(async () => dbSU("select count(*) from public.pk_players where username='bob'") === '1');
    check('ze zitten samen aan de privétafel',
      dbSU(`select count(*) from public.pk_players pl join public.lobbies l on l.id = pl.lobby_id
             where l.is_private and l.code = '${code}'`) === '2');
    check('er wordt gedeeld aan de privétafel',
      await wacht(async () => dbSU(`select count(*) from public.pk_rounds r join public.lobbies l
        on l.id = r.lobby_id where l.code = '${code}' and r.settled_at is null`) === '1', 20000));
    check('fiches kloppen', geld() === 2000, 'totaal ' + geld());

    for (const [n, p] of [['ann', ann], ['bob', bob]]) {
      check('geen fouten in de pagina van ' + n, p.fouten.length === 0, p.fouten.slice(0, 3).join(' | '));
    }
  } finally {
    await browser.close();
  }
  console.log('\nmis: ' + mis);
  process.exit(mis ? 1 : 0);
})().catch(e => { console.error(e); process.exit(1); });
