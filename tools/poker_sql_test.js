// Legt de handbeoordelaar in SQL naast die in JavaScript. Ze moeten op elke hand hetzelfde
// zeggen, anders zijn de server en de browser het oneens over wie de pot krijgt -- en dan
// ziet een speler zichzelf winnen terwijl het geld naar een ander gaat.
//
//   node tools/poker_sql_test.js [aantal handen]
//
// Vraagt een Postgres op /tmp/pgpoker/sock waar sql/poker.sql en sql/poker_rpc.sql in
// staan. Zie sql/README.md voor hoe je die opzet.
const { execFileSync } = require('child_process');
const { lees } = require('./odds.js');
const O = lees();

const RANGEN = ['2','3','4','5','6','7','8','9','T','J','Q','K','A'];
const KLEUREN = ['s','h','d','c'];
const pak = [];
for (const r of RANGEN) for (const k of KLEUREN) pak.push(r + k);

const KLEUR = { s: '♠', h: '♥', d: '♦', c: '♣' };
const naarJs = t => ({ r: t[0] === 'T' ? '10' : t.slice(0, -1), s: KLEUR[t.slice(-1)] });

// Een vaste reeks, zodat dit elke keer dezelfde handen pakt.
let zaad = 20260922;
const volgende = () => { zaad = (zaad * 48271) % 2147483647; return zaad / 2147483647; };

const handen = [];
const N = Number(process.argv[2] || 400);
for (let i = 0; i < N; i++) {
  const over = pak.slice();
  const h = [];
  for (let j = 0; j < 7; j++) h.push(over.splice(Math.floor(volgende() * over.length), 1)[0]);
  handen.push(h);
}

// Alles in één vraag aan de database, anders duurt het eeuwen.
const sql = handen.map(h => `select public.pk_score(array['${h.join("','")}'])`).join(' union all ');
require('fs').writeFileSync('/tmp/poker_kruis.sql', sql + ';\n');
const uit = execFileSync('su', ['postgres', '-c',
  'psql -h /tmp/pgpoker/sock -U postgres -qtA -f /tmp/poker_kruis.sql'],
  { encoding: 'utf8', maxBuffer: 64 * 1024 * 1024 });
const sqlScores = uit.trim().split('\n').map(x => Number(x));

let oneens = 0;
for (let i = 0; i < handen.length; i++) {
  const js = O.pokerValue(handen[i].map(naarJs));
  if (js !== sqlScores[i]) {
    if (oneens < 5) console.log('ONEENS', handen[i].join(' '), 'js=' + js, 'sql=' + sqlScores[i],
      O.pokerName(handen[i].map(naarJs)));
    oneens++;
  }
}
console.log(`${handen.length} handen, ${oneens} keer oneens`);

// En het gaat niet alleen om gelijke getallen: de VOLGORDE moet kloppen. Twee handen die
// in JavaScript gelijk staan, moeten dat in SQL ook doen.
let volgordeFout = 0;
for (let i = 0; i + 1 < handen.length; i += 2) {
  const a = O.pokerValue(handen[i].map(naarJs)), b = O.pokerValue(handen[i + 1].map(naarJs));
  const sa = sqlScores[i], sb = sqlScores[i + 1];
  const jsCmp = Math.sign(a - b), sqlCmp = Math.sign(sa - sb);
  if (jsCmp !== sqlCmp) volgordeFout++;
}
console.log(`${Math.floor(handen.length / 2)} vergelijkingen, ${volgordeFout} keer een andere winnaar`);
process.exit(oneens || volgordeFout ? 1 : 0);
