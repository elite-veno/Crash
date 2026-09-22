// Plakt de vier SQL-bestanden achter elkaar tot sql/alles.sql, in de volgorde waarin ze
// moeten draaien. De losse bestanden blijven de bron; alles.sql is er een afdruk van.
//
//   node tools/bouw_alles.js
//
// Draai dit opnieuw zodra je iets in een van de vier verandert, anders loopt de afdruk
// achter op de bron -- en dan draait er in Supabase iets anders dan er in git staat.
const fs = require('fs');
const path = require('path');
const map = path.join(__dirname, '..', 'sql');

const DELEN = [
  ['poker.sql',        '1 van 4 -- DE TABELLEN EN VIEWS'],
  ['poker_rpc.sql',    '2 van 4 -- DE FUNCTIES'],
  ['sprint_reset.sql', '3 van 4 -- DE SPRINTRESET'],
  ['poker_ledger.sql', '4 van 4 -- HET GROOTBOEK'],
];

const streep = '-- ' + '='.repeat(76) + '\n';
const kop = fs.readFileSync(path.join(__dirname, 'alles_kop.txt'), 'utf8');

let uit = kop;
for (const [naam, titel] of DELEN) {
  uit += '\n\n' + streep + '--  ' + titel + '   (sql/' + naam + ')\n' + streep + '\n';
  uit += fs.readFileSync(path.join(map, naam), 'utf8').replace(/\s+$/, '') + '\n';
}
fs.writeFileSync(path.join(map, 'alles.sql'), uit);
console.log('sql/alles.sql: ' + uit.split('\n').length + ' regels uit ' + DELEN.length + ' bestanden');
