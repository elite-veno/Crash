// Plakt de vier SQL-bestanden achter elkaar tot sql/alles.sql, in de volgorde waarin ze
// moeten draaien, en knipt datzelfde geheel op in kleine delen in sql/delen/ voor wie het
// niet in één keer kan plakken. De losse bestanden blijven de bron; alles.sql en de delen
// zijn er afdrukken van.
//
//   node tools/bouw_alles.js          delen van hoogstens ~150 regels
//   node tools/bouw_alles.js 80       kleinere delen
//
// Draai dit opnieuw zodra je iets in een van de vier verandert, anders lopen de afdrukken
// achter op de bron -- en dan draait er in Supabase iets anders dan er in git staat.
const fs = require('fs');
const path = require('path');
const map = path.join(__dirname, '..', 'sql');
const MAX = Number(process.argv[2] || 150);

const DELEN = [
  ['poker.sql',        '1 van 4 -- DE TABELLEN EN VIEWS'],
  ['poker_rpc.sql',    '2 van 4 -- DE FUNCTIES'],
  ['sprint_reset.sql', '3 van 4 -- DE SPRINTRESET'],
  ['poker_ledger.sql', '4 van 4 -- HET GROOTBOEK'],
];

const streep = '-- ' + '='.repeat(76) + '\n';

// ---------- alles.sql ----------
const kop = fs.readFileSync(path.join(__dirname, 'alles_kop.txt'), 'utf8');
let alles = kop;
const bronnen = [];
for (const [naam, titel] of DELEN) {
  const tekst = fs.readFileSync(path.join(map, naam), 'utf8').replace(/\s+$/, '') + '\n';
  bronnen.push({ naam, tekst });
  alles += '\n\n' + streep + '--  ' + titel + '   (sql/' + naam + ')\n' + streep + '\n' + tekst;
}
fs.writeFileSync(path.join(map, 'alles.sql'), alles);

// ---------- opdrachten vinden ----------
// Een opdracht eindigt op een `;` die NIET in een tekst, commentaar of functiebody staat.
// Dat onderscheid is het hele werk: een functie zit vol puntkomma's, en wie daar knipt
// krijgt een halve functie die Supabase weigert -- of erger, een die net wel doorgaat.
// Nederlands commentaar zit bovendien vol apostroffen ('s avonds), dus commentaar moet
// eerst herkend worden, anders lijkt een apostrof het begin van een tekst.
function opdrachten(sql) {
  const uit = [];
  let begin = 0, i = 0;
  const n = sql.length;
  while (i < n) {
    const c = sql[i], d = sql[i + 1];
    if (c === '-' && d === '-') { const e = sql.indexOf('\n', i); i = e < 0 ? n : e + 1; continue; }
    if (c === '/' && d === '*') { const e = sql.indexOf('*/', i + 2); i = e < 0 ? n : e + 2; continue; }
    if (c === "'") {
      i++;
      while (i < n) {
        if (sql[i] === "'" && sql[i + 1] === "'") { i += 2; continue; }
        if (sql[i] === "'") { i++; break; }
        i++;
      }
      continue;
    }
    if (c === '$') {
      const m = /^\$([A-Za-z_][A-Za-z0-9_]*)?\$/.exec(sql.slice(i));
      if (m) {
        const tag = m[0];
        const e = sql.indexOf(tag, i + tag.length);
        if (e < 0) throw new Error('dollar-quote ' + tag + ' wordt nergens gesloten');
        i = e + tag.length;
        continue;
      }
    }
    if (c === ';') {
      i++;
      // De rest van de regel hoort er nog bij (vaak een kort commentaar).
      const e = sql.indexOf('\n', i);
      const regelEind = e < 0 ? n : e + 1;
      if (/^[ \t]*(--.*)?\r?\n?$/.test(sql.slice(i, regelEind))) i = regelEind;
      uit.push(sql.slice(begin, i));
      begin = i;
      continue;
    }
    i++;
  }
  const rest = sql.slice(begin);
  if (rest.trim()) {
    // Alleen commentaar mag er na de laatste opdracht nog staan.
    const zonder = rest.replace(/--.*$/gm, '').trim();
    if (zonder) throw new Error('er staat iets na de laatste puntkomma: ' + zonder.slice(0, 80));
    uit.push(rest);
  }
  return uit;
}

// ---------- in delen ----------
const stukken = [];
for (const b of bronnen) {
  for (const o of opdrachten(b.tekst)) stukken.push({ bron: b.naam, tekst: o });
}
const regels = t => t.split('\n').length - 1;

const pakketten = [];
let huidig = null;
for (const s of stukken) {
  const r = regels(s.tekst);
  if (huidig && huidig.regels + r > MAX && huidig.regels > 0) { pakketten.push(huidig); huidig = null; }
  if (!huidig) huidig = { stukken: [], regels: 0, bronnen: new Set() };
  huidig.stukken.push(s);
  huidig.regels += r;
  huidig.bronnen.add(s.bron);
}
if (huidig) pakketten.push(huidig);

// Een deel dat alleen uit commentaar bestaat, heeft geen zin: voeg het bij het volgende.
for (let k = pakketten.length - 2; k >= 0; k--) {
  const alleenCommentaar = pakketten[k].stukken.every(s => !s.tekst.replace(/--.*$/gm, '').trim());
  if (alleenCommentaar) {
    pakketten[k + 1].stukken.unshift(...pakketten[k].stukken);
    pakketten[k + 1].regels += pakketten[k].regels;
    pakketten.splice(k, 1);
  }
}

const delenMap = path.join(map, 'delen');
fs.mkdirSync(delenMap, { recursive: true });
for (const f of fs.readdirSync(delenMap)) if (/^deel_\d+\.sql$/.test(f)) fs.unlinkSync(path.join(delenMap, f));

const totaal = pakketten.length;
const pad2 = k => String(k).padStart(2, '0');
pakketten.forEach((p, k) => {
  const nr = k + 1;
  const bronnenLijst = [...new Set(p.stukken.map(s => s.bron))].map(b => 'sql/' + b).join(', ');
  const kopDeel =
    streep +
    '--  DEEL ' + nr + ' VAN ' + totaal + '\n' +
    streep +
    '--\n' +
    (nr === 1
      ? '--  Begin hier. Plak dit deel in de SQL-editor van Supabase en druk op RUN.\n' +
        '--  Pas als dat gelukt is (groen, "Success"), ga je door met deel 2.\n'
      : '--  Plak dit pas NA deel ' + (nr - 1) + '. Die volgorde doet ertoe: dit deel gebruikt\n' +
        '--  wat de delen ervoor hebben aangemaakt.\n') +
    '--\n' +
    '--  Gaat er iets mis, draai dan niet verder -- kijk eerst wat er fout ging. Alles is\n' +
    '--  veilig om opnieuw te draaien, dus een deel nog een keer plakken kan altijd.\n' +
    '--\n' +
    '--  Uit: ' + bronnenLijst + '\n' +
    (nr === totaal
      ? '--\n--  DIT IS HET LAATSTE DEEL. Kijk hierna nog één ding na:\n' +
        '--  Settings -> API -> Exposed schemas moet ALLEEN `public` bevatten. Het schema\n' +
        '--  `poker` mag daar nooit bij -- daar liggen de holekaarten en de zaadjes.\n'
      : '') +
    streep + '\n';
  fs.writeFileSync(path.join(delenMap, 'deel_' + pad2(nr) + '.sql'),
    kopDeel + p.stukken.map(s => s.tekst).join('').replace(/\s+$/, '') + '\n');
});

console.log('sql/alles.sql: ' + alles.split('\n').length + ' regels uit ' + DELEN.length + ' bestanden');
console.log('sql/delen/:    ' + totaal + ' delen, grootste ' +
  Math.max(...pakketten.map(p => p.regels)) + ' regels (doel ' + MAX + ')');

// ---------- alles in één tekstbestand, per deel gemarkeerd ----------
// Voor wie niet alles in één keer kan plakken, maar ook geen veertien losse bestanden wil.
// Eén .txt die op elke telefoon opengaat, met de delen onder elkaar. De scheidingslijnen
// zijn SQL-commentaar: kopieer je een regel te veel mee, dan doet dat niets. En omdat
// alles ertussen gewoon SQL is, draait het hele bestand in één keer ook -- voor wie het
// wel in één keer kan plakken.
const hekjes = '-- ' + '#'.repeat(76) + '\n';
let txt =
  hekjes +
  '--  CRASH CASINO -- ALLE SQL, IN ' + totaal + ' DELEN\n' +
  hekjes +
  '--\n' +
  '--  Te groot om in één keer te plakken? Doe het dan per deel:\n' +
  '--\n' +
  '--    1. Zoek hieronder "DEEL 1 VAN ' + totaal + '".\n' +
  '--    2. Kopieer alles vanaf die regel tot aan "EINDE DEEL 1".\n' +
  '--    3. Plak het in de SQL-editor van Supabase en druk op RUN.\n' +
  '--    4. Pas als je groen "Success" ziet: door naar DEEL 2. Enzovoort.\n' +
  '--\n' +
  '--  De volgorde doet ertoe: elk deel gebruikt wat de delen ervoor hebben aangemaakt.\n' +
  '--  Gaat er iets mis, ga dan niet verder. Alles is veilig om opnieuw te draaien.\n' +
  '--\n' +
  '--  Kan het wel in één keer? Dan mag je ook dit hele bestand plakken. De regels met\n' +
  '--  hekjes zijn commentaar en doen niets.\n' +
  '--\n' +
  '--  Er staat hier geen enkele sleutel in. De service_role-sleutel hoort nergens anders\n' +
  '--  dan in het dashboard van Supabase.\n' +
  '--\n' +
  hekjes;

pakketten.forEach((p, k) => {
  const nr = k + 1;
  const inhoud = fs.readFileSync(path.join(delenMap, 'deel_' + pad2(nr) + '.sql'), 'utf8');
  const titel = '   DEEL ' + nr + ' VAN ' + totaal + '   ';
  const breed = 76, links = Math.floor((breed - titel.length) / 2);
  txt += '\n\n\n' + hekjes +
    '-- ' + '#'.repeat(links) + titel + '#'.repeat(breed - links - titel.length) + '\n' +
    '-- ####  kopieer vanaf hier\n' +
    hekjes + '\n' + inhoud.replace(/\s+$/, '') + '\n\n' +
    hekjes +
    '-- ####  EINDE DEEL ' + nr + ' -- kopieer tot hier' +
    (nr < totaal ? ', RUN, en dan door naar deel ' + (nr + 1) : ', RUN -- en dan ben je klaar') + '\n' +
    hekjes;
});
fs.writeFileSync(path.join(map, 'alles_in_delen.txt'), txt);
console.log('sql/alles_in_delen.txt: ' + txt.split('\n').length + ' regels, ' + totaal + ' delen');
