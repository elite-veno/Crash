// Haalt `const ODDS` uit crash.html en geeft het terug als een gewoon object, zodat de
// wiskunde van elk spel te testen is zonder browser. De pagina is één bestand en blijft
// dat; dit leest eruit, het schrijft er niets in.
//
// Het blok staat tussen twee vaste regels in crash.html. Verandert een van die twee, dan
// stopt dit met een duidelijke fout in plaats van stilletjes een leeg object terug te
// geven -- want dan zouden alle tests slagen zonder iets te toetsen.
const fs = require('fs');
const path = require('path');

const PAGINA = path.join(__dirname, '..', 'crash.html');
const BEGIN = 'const ODDS = {';
const EIND = '// =================== END ODDS ===================';
// ODDS leunt op een paar helpers uit de UTIL-sectie erboven (randInt om te schudden,
// round2 en floor2 om af te ronden). Die gaan mee; alles wat de DOM aanraakt blijft eruit.
const HELPERS = `
const round2 = n => Math.round(n * 100) / 100;
const floor2 = n => Math.floor(n * 100 + 1e-9) / 100;
const randInt = n => Math.floor(Math.random() * n);
const MIN_BET = 1;
`;

function lees() {
  const bron = fs.readFileSync(PAGINA, 'utf8');
  const i = bron.indexOf(BEGIN);
  if (i < 0) throw new Error('ODDS niet gevonden in crash.html (zoekt naar: ' + BEGIN + ')');
  const j = bron.indexOf(EIND, i);
  if (j < 0) throw new Error('einde van ODDS niet gevonden in crash.html');
  const blok = bron.slice(i, j);
  // Alles tot en met de afsluitende `};` van het object zelf.
  const eind = blok.lastIndexOf('};');
  if (eind < 0) throw new Error('ODDS wordt niet afgesloten met };');
  const code = blok.slice(0, eind + 2);
  // eslint-disable-next-line no-new-func
  return new Function(HELPERS + code + '\nreturn ODDS;')();
}

module.exports = { lees, PAGINA };
