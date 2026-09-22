// Het kleinste testharnas dat werkt: tellen wat er slaagt, zeggen wat er faalt, en aan het
// eind met een nette afsluitcode stoppen zodat een script eromheen weet hoe het ging.
let geslaagd = 0;
const gefaald = [];

function check(wat, verwacht, gekregen) {
  const a = JSON.stringify(verwacht);
  const b = JSON.stringify(gekregen);
  if (a === b) { geslaagd++; return true; }
  gefaald.push({ wat, verwacht: a, gekregen: b });
  return false;
}

function bijna(wat, verwacht, gekregen, marge = 1e-9) {
  if (Number.isFinite(gekregen) && Math.abs(verwacht - gekregen) <= marge) { geslaagd++; return true; }
  gefaald.push({ wat, verwacht: String(verwacht) + ' (±' + marge + ')', gekregen: String(gekregen) });
  return false;
}

function waar(wat, gekregen) { return check(wat, true, !!gekregen); }

function rapport(naam) {
  if (!gefaald.length) {
    console.log(`${naam}: ${geslaagd} geslaagd, 0 gefaald`);
    return 0;
  }
  for (const f of gefaald) {
    console.log(`  FOUT  ${f.wat}\n        verwacht: ${f.verwacht}\n        gekregen: ${f.gekregen}`);
  }
  console.log(`${naam}: ${geslaagd} geslaagd, ${gefaald.length} GEFAALD`);
  return 1;
}

module.exports = { check, bijna, waar, rapport };
