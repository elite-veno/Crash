// De handbeoordelaar van poker. Hier spelen mensen tegen elkaar in plaats van tegen het
// huis, dus een fout is niet een scheve uitbetaling maar iemands pot die naar de verkeerde
// gaat. Vandaar dat dit de gevallen afloopt die aan een echte tafel voorkomen, inclusief
// de vervelende: het wiel, twee straten die gelijk eindigen, drie paren in zeven kaarten,
// en een kleur die hoger is dan een andere kleur.
//
//   node tools/poker_test.js
const { lees } = require('./odds.js');
const h = require('./harness.js');

const O = lees();

// '9s' -> { r: '9', s: '♠' }. Tien schrijf je als T.
const KLEUR = { s: '♠', h: '♥', d: '♦', c: '♣' };
const k = t => ({ r: t[0] === 'T' ? '10' : t.slice(0, -1), s: KLEUR[t.slice(-1)] });
const hand = s => s.split(' ').map(k);
const waarde = s => O.pokerValue(hand(s));
const naam = s => O.pokerName(hand(s));

// ---------- elke soort hand wordt herkend ----------
h.check('straight flush', 'straight flush', naam('9s Ts Js Qs Ks 2h 3d'));
h.check('vier gelijke', 'four of a kind', naam('9s 9h 9d 9c Ks 2h 3d'));
h.check('full house', 'full house', naam('9s 9h 9d Ks Kh 2d 3c'));
h.check('kleur', 'flush', naam('2s 5s 9s Js Ks 3h 4d'));
h.check('straat', 'straight', naam('9s Th Jd Qc Ks 2h 3d'));
h.check('drie gelijke', 'three of a kind', naam('9s 9h 9d Ks 4h 2d 3c'));
h.check('twee paar', 'two pair', naam('9s 9h Kd Kc 4h 2d 3c'));
h.check('paar', 'pair', naam('9s 9h Kd 7c 4h 2d 3c'));
h.check('hoge kaart', 'high card', naam('9s 5h Kd 7c 4h 2d 3c'));

// ---------- het aas staat aan beide kanten van een straat ----------
h.check('het wiel is een straat', 'straight', naam('As 2h 3d 4c 5s Kh Qd'));
h.check('en in één kleur een straight flush', 'straight flush', naam('As 2s 3s 4s 5s Kh Qd'));
h.check('de hoogste straat eindigt op het aas', 'straight', naam('Ts Jh Qd Kc As 2h 3d'));
h.waar('een straat op het aas slaat het wiel',
  waarde('Ts Jh Qd Kc As 2h 3d') > waarde('As 2h 3d 4c 5s Kh Qd'));
h.waar('het wiel is de laagste straat, lager dan zes-hoog',
  waarde('2s 3h 4d 5c 6s Kh Qd') > waarde('As 2h 3d 4c 5s Kh Qd'));
// En het wiel is geen "aas hoog": de vijf telt als de top.
h.check('het wiel telt als vijf-hoog', [5, 0, 0, 0, 0], O.pokerScore(hand('As 2h 3d 4c 5s Kh Qd')).sleutels);

// ---------- de valkuil: een straat mag niet over twee kleuren lopen ----------
h.check('vijf op een rij in twee kleuren is geen straight flush', 'straight',
  naam('9s Ts Js Qs Kh 2d 3c'));
// Zes kaarten van één kleur waarvan er vijf op een rij staan: dat is er wel een.
h.check('zes in één kleur met een straat erin', 'straight flush',
  naam('9s Ts Js Qs Ks 2s 3d'));
// Een kleur met een straat erin die er NIET in past: alleen de kleur telt.
h.check('kleur zonder straat in die kleur', 'flush', naam('2s 5s 9s Js Ks Th Qd'));

// ---------- kickers ----------
h.waar('vier gelijke: de kicker beslist',
  waarde('9s 9h 9d 9c Ks 2h 3d') > waarde('9s 9h 9d 9c Qs 2h 3d'));
h.waar('drie gelijke: de eerste kicker beslist',
  waarde('9s 9h 9d Ks 4h 2d 3c') > waarde('9s 9h 9d Qs 4h 2d 3c'));
h.waar('drie gelijke: en anders de tweede',
  waarde('9s 9h 9d Ks 5h 2d 3c') > waarde('9s 9h 9d Ks 4h 2d 3c'));
h.waar('paar: drie kickers tellen mee',
  waarde('9s 9h Kd Qc 5h 2d 3c') > waarde('9s 9h Kd Qc 4h 2d 3c'));
h.waar('twee paar: het hoogste paar eerst',
  waarde('Ks Kh 2d 2c 5h 7d 8c') > waarde('Qs Qh Jd Jc 5h 7d 8c'));
h.waar('twee paar: dan het tweede paar',
  waarde('Ks Kh Jd Jc 5h 7d 8c') > waarde('Ks Kh Td Tc 5h 7d 8c'));
h.waar('twee paar: dan de kicker',
  waarde('Ks Kh Jd Jc Ah 7d 8c') > waarde('Ks Kh Jd Jc 9h 7d 8c'));
h.waar('hoge kaart: de vijfde kaart kan beslissen',
  waarde('Ks Qh Jd 9c 8h 2d 3c') > waarde('Ks Qh Jd 9c 7h 2d 3c'));

// ---------- drie paren in zeven kaarten ----------
// Er tellen er maar twee. Het derde paar doet niet mee, maar de hoogste kaart ervan kan
// wel de kicker zijn -- en dat is precies waar een beoordelaar de mist in gaat.
{
  const s = O.pokerScore(hand('Ks Kh Qd Qc 2h 2d 7c'));
  h.check('drie paren: de twee hoogste tellen', [13, 12], s.sleutels.slice(0, 2));
  h.check('en de kicker is de hoogste van de rest', 7, s.sleutels[2]);
}
{
  // Zonder losse kaart hoger dan het derde paar is die derde paarkaart de kicker.
  const s = O.pokerScore(hand('Ks Kh Qd Qc 9h 9d 3c'));
  h.check('het derde paar levert de kicker', 9, s.sleutels[2]);
}

// ---------- full house uit twee drietallen ----------
h.check('twee drietallen worden een full house', 'full house', naam('9s 9h 9d Ks Kh Kd 3c'));
{
  const s = O.pokerScore(hand('9s 9h 9d Ks Kh Kd 3c'));
  h.check('het hoogste drietal is de drie, het andere het paar', [13, 9], s.sleutels.slice(0, 2));
}

// ---------- gelijk is echt gelijk ----------
h.check('dezelfde hand in andere kleuren is gelijk',
  waarde('9s 9h Kd Qc 5h 2d 3c'), waarde('9d 9c Kh Qs 5d 2h 3s'));
h.check('een gedeelde pot op het bord: beide spelers spelen het bord',
  waarde('2h 3d Ts Js Qs Ks As'), waarde('4h 5d Ts Js Qs Ks As'));

// ---------- de volgorde van alle negen soorten ----------
{
  const oplopend = [
    'high card       2s 5h 9d Jc Kh 3d 4c',
    'pair            2s 2h 9d Jc Kh 3d 4c',
    'two pair        2s 2h 9d 9c Kh 3d 4c',
    'three of a kind 2s 2h 2d 9c Kh 3d 4c',
    'straight        5s 6h 7d 8c 9h 2d 3c',
    'flush           2s 5s 9s Js Ks 3h 4d',
    'full house      2s 2h 2d 9c 9h 3d 4c',
    'four of a kind  2s 2h 2d 2c 9h 3d 4c',
    'straight flush  5s 6s 7s 8s 9s 2d 3c',
  ];
  let vorige = -1;
  for (const regel of oplopend) {
    const naamVerwacht = regel.slice(0, 15).trim();
    const kaarten = regel.slice(15).trim();
    h.check('herkend: ' + naamVerwacht, naamVerwacht, naam(kaarten));
    const v = waarde(kaarten);
    h.waar(naamVerwacht + ' slaat alles eronder', v > vorige);
    vorige = v;
  }
}

// ---------- geen twee handen krijgen per ongeluk dezelfde score ----------
// Elke hand van vijf uit een vol pak, en dan kijken of twee verschillende categorieën
// elkaar ergens overlappen. Dat is waar een bitmasker zich vergist.
{
  const pak = [];
  for (const s of ['s', 'h', 'd', 'c']) for (const r of ['2','3','4','5','6','7','8','9','T','J','Q','K','A']) pak.push(k(r + s));
  const perCat = new Map();
  for (let a = 0; a < 52; a++) for (let b = a + 1; b < 52; b++) for (let c = b + 1; c < 52; c++)
    for (let d = c + 1; d < 52; d++) for (let e = d + 1; e < 52; e++) {
      const sc = O.pokerScore([pak[a], pak[b], pak[c], pak[d], pak[e]]);
      let v = sc.cat;
      for (const x of sc.sleutels) v = v * 15 + x;
      if (!perCat.has(sc.cat)) perCat.set(sc.cat, { min: v, max: v, n: 0 });
      const g = perCat.get(sc.cat);
      if (v < g.min) g.min = v;
      if (v > g.max) g.max = v;
      g.n++;
    }
  h.check('alle negen soorten komen voor in een vol pak', 9, perCat.size);
  // De bekende aantallen uit een pak van 52, vijf kaarten:
  h.check('40 straight flushes', 40, perCat.get(8).n);
  h.check('624 vierlingen', 624, perCat.get(7).n);
  h.check('3744 full houses', 3744, perCat.get(6).n);
  h.check('5108 kleuren', 5108, perCat.get(5).n);
  h.check('10200 straten', 10200, perCat.get(4).n);
  h.check('54912 drietallen', 54912, perCat.get(3).n);
  h.check('123552 twee paar', 123552, perCat.get(2).n);
  h.check('1098240 paren', 1098240, perCat.get(1).n);
  h.check('1302540 hoge kaarten', 1302540, perCat.get(0).n);
  // En geen enkele categorie loopt in de volgende over.
  for (let c = 0; c < 8; c++) {
    h.waar('categorie ' + c + ' blijft onder ' + (c + 1),
      perCat.get(c).max < perCat.get(c + 1).min);
  }
}

// ================== DE GEVALLEN UIT DE ONTWERPRONDE ==================
// Een ontwerpronde met review-agenten leverde deze lijst op: de handen waar een
// beoordelaar zich op verkijkt. Ze staan hier apart, want ze zijn stuk voor stuk een
// verhaal.
{
  // Vier kaarten op weg naar een straight flush, plus een vijfde van dezelfde kleur die er
  // niet bij hoort. Er is een flush EN een straat, en de flush wint. Wie de straat op het
  // masker van de hele hand toetst in plaats van op dat van de flushkleur, betaalt dit uit
  // als straight flush.
  h.check('flush en straat door elkaar: de flush wint', 'flush', naam('2h 3h 4h 5h 6s 9d Kh'));
  h.check('en andersom net zo', 'flush', naam('2h 3h 4h 5s 6h 9h Kh'));
}
{
  // Zeven kaarten van één kleur: de vijf hoogste tellen.
  const s = O.pokerScore(hand('2h 3h 4h 8h Th Kh 9s'));
  h.check('van zes in één kleur tellen de vijf hoogste', [13, 10, 8, 4, 3], s.sleutels);
}
{
  // Twee drietallen worden een full house, en de tweede telt als het paar.
  h.check('twee drietallen', 'full house', naam('9h 9s 9d 7h 7s 7d 2c'));
  h.check('negens vol zevens', [9, 7], O.pokerScore(hand('9h 9s 9d 7h 7s 7d 2c')).sleutels.slice(0, 2));
}
{
  // Een aas alleen maakt nog geen wiel: er moeten vijf op een rij liggen.
  h.check('een aas zonder de rest is hoge kaart', 'high card', naam('Ah 2s 3d 4c 9h Kd Qc'));
}
{
  // Twee spelers die allebei het bord spelen, met verschillende eigen kaarten: exact gelijk.
  h.check('een bord dat zichzelf speelt is voor allebei hetzelfde',
    waarde('2c 3d Th Jh Qh Kh Ah'), waarde('4c 5d Th Jh Qh Kh Ah'));
}

// ================== DE POT VERDELEN ==================
// Hier gaat het geld heen, dus hier telt vooral één ding: wat erin gaat komt er ook weer
// uit. Geen cent erbij, geen cent kwijt -- bij elke verdeling hieronder wordt dat geteld.
const pot = (spelers, knop = 0) => O.pokerPots(spelers, knop);
function sluitend(wat, spelers, knop = 0) {
  const uit = pot(spelers, knop);
  const in_ = spelers.reduce((a, s) => a + Math.round(s.ingezet * 100), 0);
  const eruit = Object.values(uit).reduce((a, b) => a + Math.round(b * 100), 0);
  h.check(wat + ': erin is eruit', in_, eruit);
  return uit;
}

{
  // Twee spelers, gelijke inzet, de beste wint alles.
  const u = sluitend('kop-aan-kop', [
    { id: 'a', ingezet: 10, gefold: false, waarde: 200 },
    { id: 'b', ingezet: 10, gefold: false, waarde: 100 },
  ]);
  h.check('de beste hand pakt de pot', { a: 20, b: 0 }, u);
}
{
  // Gelijke handen delen.
  const u = sluitend('gedeelde pot', [
    { id: 'a', ingezet: 10, gefold: false, waarde: 150 },
    { id: 'b', ingezet: 10, gefold: false, waarde: 150 },
  ]);
  h.check('gelijk spel deelt de pot', { a: 10, b: 10 }, u);
}
{
  // Een pot die niet rond deelt: de oneven cent gaat naar links van de knop.
  const spelers = [
    { id: 'a', ingezet: 0.05, gefold: false, waarde: 150 },
    { id: 'b', ingezet: 0.05, gefold: false, waarde: 150 },
    { id: 'c', ingezet: 0.05, gefold: false, waarde: 150 },
  ];
  const u = sluitend('oneven centen', spelers, 0);
  h.check('de eerste na de knop krijgt de rest', 0.05, u.a);
  h.check('de anderen krijgen gelijk op', 0.05, u.b);
  const u2 = sluitend('oneven centen, knop verschoven', spelers, 1);
  h.check('met de knop een stoel verder gaat de cent daarheen', 0.05, u2.b);
}
{
  // Wie gefold is, laat zijn geld in de pot.
  const u = sluitend('wie fold laat zijn geld staan', [
    { id: 'a', ingezet: 10, gefold: true, waarde: 999 },
    { id: 'b', ingezet: 10, gefold: false, waarde: 100 },
    { id: 'c', ingezet: 10, gefold: false, waarde: 50 },
  ]);
  h.check('de beste van wie er nog is wint alles', 30, u.b);
  h.check('en de folder krijgt niets, hoe goed zijn hand ook was', 0, u.a);
}
{
  // De klassieke zijpot: A all-in voor 20 met de beste hand, B en C gaan door tot 50.
  const u = sluitend('één zijpot', [
    { id: 'a', ingezet: 20, gefold: false, waarde: 300 },
    { id: 'b', ingezet: 50, gefold: false, waarde: 200 },
    { id: 'c', ingezet: 50, gefold: false, waarde: 100 },
  ]);
  h.check('all-in pakt de hoofdpot, niet meer', 60, u.a);
  h.check('de zijpot gaat naar de beste van de rest', 60, u.b);
  h.check('en de derde krijgt niets', 0, u.c);
}
{
  // Drie all-ins op drie hoogtes, met de beste hand onderaan.
  const u = sluitend('drie hoogtes', [
    { id: 'a', ingezet: 10, gefold: false, waarde: 300 },
    { id: 'b', ingezet: 30, gefold: false, waarde: 200 },
    { id: 'c', ingezet: 60, gefold: false, waarde: 100 },
  ]);
  h.check('de kleinste stapel wint drie keer zijn eigen inzet', 30, u.a);
  h.check('de middelste wint de tweede laag', 40, u.b);
  h.check('en de grootste houdt wat niemand kon matchen', 30, u.c);
}
{
  // Dezelfde drie hoogtes, maar nu wint de grootste stapel alles.
  const u = sluitend('grootste stapel wint alles', [
    { id: 'a', ingezet: 10, gefold: false, waarde: 100 },
    { id: 'b', ingezet: 30, gefold: false, waarde: 200 },
    { id: 'c', ingezet: 60, gefold: false, waarde: 300 },
  ]);
  h.check('die pakt alles', 100, u.c);
  h.check('de anderen niets', 0, u.a + u.b);
}
{
  // Een gedeelde hoofdpot naast een zijpot die één speler alleen wint.
  const u = sluitend('gedeelde hoofdpot, eigen zijpot', [
    { id: 'a', ingezet: 20, gefold: false, waarde: 300 },
    { id: 'b', ingezet: 50, gefold: false, waarde: 300 },
    { id: 'c', ingezet: 50, gefold: false, waarde: 100 },
  ]);
  h.check('de hoofdpot wordt gedeeld', 30, u.a);
  h.check('en de zijpot is voor wie er alleen om speelde', 90, u.b);
}
{
  // Geld van een gefolde speler telt mee in de laag waarin hij zat, ook al speelt hij niet
  // meer mee. Dat is waar een verdeling vaak scheef gaat.
  const u = sluitend('gefold geld telt mee in zijn eigen laag', [
    { id: 'a', ingezet: 10, gefold: false, waarde: 300 },
    { id: 'b', ingezet: 25, gefold: true,  waarde: 999 },
    { id: 'c', ingezet: 50, gefold: false, waarde: 200 },
    { id: 'd', ingezet: 50, gefold: false, waarde: 100 },
  ]);
  h.check('de all-in wint vier keer tien', 40, u.a);
  h.check('de rest gaat naar de beste van wie er nog is', 95, u.c);
  h.check('de folder krijgt niets terug', 0, u.b);
}
{
  // Niemand hoefde de laatste verhoging te matchen: dat geld hoort terug naar wie het
  // stortte, niet naar de winnaar van de hand.
  const u = sluitend('een verhoging die niemand matcht komt terug', [
    { id: 'a', ingezet: 10, gefold: true,  waarde: 0 },
    { id: 'b', ingezet: 10, gefold: true,  waarde: 0 },
    { id: 'c', ingezet: 40, gefold: false, waarde: 100 },
  ]);
  h.check('wie overblijft krijgt de pot plus zijn eigen overschot', 60, u.c);
}
{
  // Een laag waar niemand meer om speelt omdat iedereen die eraan meedeed gepast is. Die
  // hoort NAAR RATO terug naar wie hem volstortte. Hier legden a en b allebei 40 in en
  // zijn allebei gepast; c deed 10 en wint. De laag van 10 tot 40 is van a en b samen, dus
  // 30 elk -- niet 60 voor een van de twee, wat de code eerst deed.
  const u = sluitend('een dode laag gaat naar rato terug', [
    { id: 'a', ingezet: 40, gefold: true,  waarde: 0 },
    { id: 'b', ingezet: 40, gefold: true,  waarde: 0 },
    { id: 'c', ingezet: 10, gefold: false, waarde: 100 },
  ]);
  h.check('c wint de hoofdpot van drie keer tien', 30, u.c);
  h.check('a krijgt zijn eigen overschot terug', 30, u.a);
  h.check('en b het zijne', 30, u.b);
}
{
  // Iedereen fold behalve één: die krijgt de hele pot zonder te hoeven laten zien.
  const u = sluitend('iedereen fold behalve één', [
    { id: 'a', ingezet: 5,  gefold: true,  waarde: 0 },
    { id: 'b', ingezet: 15, gefold: true,  waarde: 0 },
    { id: 'c', ingezet: 15, gefold: false, waarde: 1 },
  ]);
  h.check('de laatste die er nog zit pakt alles', 35, u.c);
}
{
  // Zes spelers, allemaal een ander bedrag, twee gelijke beste handen: het zwaarste geval
  // dat aan een tafel van zes kan voorkomen.
  const u = sluitend('zes spelers, alles door elkaar', [
    { id: 'a', ingezet: 5,   gefold: false, waarde: 500 },
    { id: 'b', ingezet: 12,  gefold: true,  waarde: 0 },
    { id: 'c', ingezet: 40,  gefold: false, waarde: 500 },
    { id: 'd', ingezet: 40,  gefold: false, waarde: 300 },
    { id: 'e', ingezet: 100, gefold: false, waarde: 200 },
    { id: 'f', ingezet: 100, gefold: true,  waarde: 0 },
  ], 0);
  // De hoofdpot (tot 5) is 30 en wordt door a en c gedeeld.
  h.check('a deelt de hoofdpot', 15, u.a);
}
{
  // Een pot met centen die niet rond deelt over drie winnaars.
  const u = sluitend('drie winnaars, twee centen over', [
    { id: 'a', ingezet: 3.34, gefold: false, waarde: 7 },
    { id: 'b', ingezet: 3.33, gefold: false, waarde: 7 },
    { id: 'c', ingezet: 3.33, gefold: false, waarde: 7 },
  ], 0);
  const som = Math.round((u.a + u.b + u.c) * 100);
  h.check('tot op de cent verdeeld', 1000, som);
}

// ================== DE INZETRONDE ==================
// Wat een speler mag doen, en wat er gebeurt als hij het doet. Dit is de grendel: de
// browser stuurt hooguit "raise" met een bedrag, en als dat bedrag niet mag gaat de zet
// niet door. Alle bedragen in centen.
function tafel(stacks, blinds = [50, 100]) {
  const stoelen = stacks.map(x => ({ stack: x, inzet: 0, gefold: false, allin: false, gezet: false }));
  // De blinds staan er al in: de kleine op stoel 0, de grote op stoel 1.
  stoelen[0].stack -= blinds[0]; stoelen[0].inzet = blinds[0];
  stoelen[1].stack -= blinds[1]; stoelen[1].inzet = blinds[1];
  return { stoelen, hoogste: blinds[1], minVerhoging: blinds[1], beurt: 2 % stacks.length };
}

{
  const st = tafel([1000, 1000, 1000]);
  const m = O.pokerLegal(st, 2);
  h.check('wie nog niets heeft ingelegd moet de grote blind matchen', 100, m.call);
  h.check('en kan dus niet checken', false, m.check);
  h.check('de kleinste verhoging is twee blinds', 200, m.minRaise);
  h.check('en de grootste is zijn hele stapel', 1000, m.maxRaise);
}
{
  // Buiten je beurt mag niets.
  const st = tafel([1000, 1000, 1000]);
  h.check('buiten je beurt wordt geweigerd', 'not your turn', O.pokerAct(st, 0, 'call').fout);
}
{
  // Checken terwijl er een inzet staat mag niet.
  const st = tafel([1000, 1000, 1000]);
  h.check('checken kan niet als er een inzet staat', 'cannot check', O.pokerAct(st, 2, 'check').fout);
}
{
  // Een te kleine verhoging wordt geweigerd.
  const st = tafel([1000, 1000, 1000]);
  h.check('een verhoging onder het minimum mag niet', 'raise too small',
    O.pokerAct(st, 2, 'raise', 150).fout);
  h.check('precies het minimum mag wel', true, O.pokerAct(st, 2, 'raise', 200).ok);
  h.check('en de hoogste inzet staat dan op 200', 200, st.hoogste);
  h.check('de minimumverhoging blijft honderd', 100, st.minVerhoging);
}
{
  // Meer inzetten dan je hebt kan niet.
  const st = tafel([1000, 1000, 300]);
  h.check('meer dan je stapel wordt geweigerd', 'more than you have',
    O.pokerAct(st, 2, 'raise', 500).fout);
  h.check('all-in voor precies je stapel mag', true, O.pokerAct(st, 2, 'raise', 300).ok);
  h.check('en dan sta je all-in', true, st.stoelen[2].allin);
  h.check('met een lege stapel', 0, st.stoelen[2].stack);
}
{
  // Een verhoging van 100 naar 250 is 150 erbij, en dat is meer dan de minimumverhoging
  // van 100 -- dus dit is een VOLLE verhoging, en het minimum gaat mee omhoog naar 150.
  const st = tafel([1000, 1000, 250]);
  O.pokerAct(st, 2, 'raise', 250);
  h.check('de hoogste inzet staat op 250', 250, st.hoogste);
  h.check('en de minimumverhoging is nu honderdvijftig', 150, st.minVerhoging);
}
{
  // De regel die mensen verrast: een all-in die KLEINER is dan een volle verhoging
  // verhoogt de inzet wel, maar heropent de ronde niet voor wie al gezet had. Stoel 2
  // heeft maar 150 en gaat all-in: dat is 50 boven de grote blind, waar 100 voor een
  // volle verhoging nodig was.
  const st = tafel([1000, 1000, 150]);
  st.stoelen[0].gezet = true;             // de kleine blind had al gecalld
  st.stoelen[0].stack -= 50; st.stoelen[0].inzet = 100;
  h.check('all-in onder het minimum mag', true, O.pokerAct(st, 2, 'raise', 150).ok);
  h.check('de hoogste inzet gaat wel mee omhoog', 150, st.hoogste);
  h.check('maar de minimumverhoging blijft staan', 100, st.minVerhoging);
  h.check('en wie al gezet had blijft op gezet staan', true, st.stoelen[0].gezet);
  // Hij moet nog wel die vijftig bijleggen, dus de ronde is niet klaar.
  h.check('maar hij moet het verschil nog matchen', false, O.pokerRondeKlaar(st));
  h.check('en is dus weer aan de beurt', 0, O.pokerVolgende(st, 2));
  // En dan mag hij alleen callen of folden -- niet heropenen met een minimumverhoging die
  // op de te kleine all-in is gebouwd.
  const m = O.pokerLegal(st, 0);
  h.check('hij moet vijftig bijleggen', 50, m.call);
  // Stoel 0 begon met 1000, legde 50 in als kleine blind en vulde aan tot 100: hij heeft
  // nog 900 en staat op 100, dus verhogen kan tot 1000.
  h.check('en verhogen kan tot alles wat hij nog heeft', 1000, m.maxRaise);
  h.check('met als ondergrens de hoogste plus de oude minimumverhoging', 250, m.minRaise);
}
{
  // En het spiegelbeeld: een volle verhoging heropent de ronde wél.
  const st = tafel([1000, 1000, 1000]);
  O.pokerAct(st, 2, 'call');              // stoel 2 gaat mee tot 100
  st.beurt = 0; O.pokerAct(st, 0, 'call');
  st.beurt = 1; O.pokerAct(st, 1, 'check');
  h.check('iedereen heeft gezet, de ronde is klaar', true, O.pokerRondeKlaar(st));
  // Nu dezelfde tafel, maar stoel 1 verhoogt in plaats van te checken.
  const st2 = tafel([1000, 1000, 1000]);
  O.pokerAct(st2, 2, 'call');
  st2.beurt = 0; O.pokerAct(st2, 0, 'call');
  st2.beurt = 1; O.pokerAct(st2, 1, 'raise', 300);
  h.check('een volle verhoging heropent de ronde', false, O.pokerRondeKlaar(st2));
  h.check('en zet de anderen weer op niet-gezet', false, st2.stoelen[0].gezet);
  h.check('de verhoger zelf staat wel op gezet', true, st2.stoelen[1].gezet);
  h.check('de minimumverhoging is nu tweehonderd', 200, st2.minVerhoging);
}
{
  // Een ronde is klaar als iedereen gezet heeft en op dezelfde inzet staat.
  const st = tafel([1000, 1000, 1000]);
  h.check('aan het begin is de ronde niet klaar', false, O.pokerRondeKlaar(st));
  O.pokerAct(st, 2, 'call'); st.beurt = 0;
  O.pokerAct(st, 0, 'call'); st.beurt = 1;
  h.check('de grote blind mag nog reageren', 1, O.pokerVolgende(st, 0));
  O.pokerAct(st, 1, 'check');
  h.check('daarna is hij klaar', true, O.pokerRondeKlaar(st));
  h.check('en is er niemand meer aan de beurt', -1, O.pokerVolgende(st, 1));
}
{
  // Iedereen fold behalve één: klaar, ongeacht de inzetten.
  const st = tafel([1000, 1000, 1000]);
  O.pokerAct(st, 2, 'fold'); st.beurt = 0;
  O.pokerAct(st, 0, 'fold');
  h.check('met nog één speler is de ronde klaar', true, O.pokerRondeKlaar(st));
}
{
  // Iedereen all-in: er valt niets meer te doen.
  const st = tafel([200, 200, 200]);
  O.pokerAct(st, 2, 'raise', 200); st.beurt = 0;
  O.pokerAct(st, 0, 'call'); st.beurt = 1;
  O.pokerAct(st, 1, 'call');
  h.check('alle drie all-in', 3, st.stoelen.filter(x => x.allin).length);
  h.check('en dus is de ronde klaar', true, O.pokerRondeKlaar(st));
}
{
  // Een speler die all-in is, krijgt geen beurt meer.
  const st = tafel([1000, 1000, 100]);
  O.pokerAct(st, 2, 'call');   // stoel 2 gaat met zijn laatste honderd mee
  h.check('die staat all-in', true, st.stoelen[2].allin);
  h.check('en mag niets meer', false, O.pokerLegal(st, 2).fold);
  h.check('en wordt overgeslagen', 0, O.pokerVolgende(st, 2));
}
{
  // Een onzinbedrag wordt geweigerd, en een onbekende zet ook.
  const st = tafel([1000, 1000, 1000]);
  h.check('een verhoging naar niets wordt geweigerd', 'bad amount',
    O.pokerAct(st, 2, 'raise', 'veel').fout);
  h.check('een onbekende zet wordt geweigerd', 'unknown move', O.pokerAct(st, 2, 'dansen').fout);
  h.check('en de tafel is niet veranderd', 100, st.hoogste);
}
{
  // Na de flop begint iedereen op nul en mag de eerste checken.
  const st = { stoelen: [
    { stack: 900, inzet: 0, gefold: false, allin: false, gezet: false },
    { stack: 900, inzet: 0, gefold: false, allin: false, gezet: false },
  ], hoogste: 0, minVerhoging: 100, beurt: 0 };
  const m = O.pokerLegal(st, 0);
  h.check('na de flop kun je checken', true, m.check);
  h.check('er valt niets te callen', 0, m.call);
  h.check('en de kleinste inzet is een grote blind', 100, m.minRaise);
  O.pokerAct(st, 0, 'check'); st.beurt = 1;
  h.check('één check maakt de ronde nog niet klaar', 1, O.pokerVolgende(st, 0));
  O.pokerAct(st, 1, 'check');
  h.check('twee checks wel', true, O.pokerRondeKlaar(st));
}
{
  // Het geld klopt: wat van de stapels af gaat, staat in de inzetten.
  const st = tafel([1000, 1000, 1000]);
  O.pokerAct(st, 2, 'raise', 350); st.beurt = 0;
  O.pokerAct(st, 0, 'call'); st.beurt = 1;
  O.pokerAct(st, 1, 'call');
  const over = st.stoelen.reduce((a, x) => a + x.stack, 0);
  const inzet = st.stoelen.reduce((a, x) => a + x.inzet, 0);
  h.check('stapels plus inzetten is wat er begon', 3000, over + inzet);
  h.check('en iedereen staat op hetzelfde bedrag', 350, st.stoelen[0].inzet);
}


{
  // De korte all-in heropent de inzet niet. De server houdt per stoel bij of je nog mag
  // verhogen; het scherm rekent met dezelfde functie, want anders zet het een RAISE-knop
  // neer die de server daarna weigert -- en dan lijkt het spel stuk terwijl het klopt.
  const st = { stoelen: [
    { stack: 900, inzet: 100, gefold: false, allin: false, gezet: true, magVerhogen: false },
    { stack: 800, inzet: 200, gefold: false, allin: false, gezet: true },
  ], hoogste: 200, minVerhoging: 100, beurt: 0 };
  const m = O.pokerLegal(st, 0);
  h.check('na een korte all-in mag je nog callen', 100, m.call);
  h.check('en passen', true, m.fold);
  h.check('maar niet meer verhogen', 0, m.maxRaise);
  h.check('en er staat geen ondergrens meer', 0, m.minRaise);
  h.check('de zet wordt ook echt geweigerd', 'cannot raise', O.pokerAct(st, 0, 'raise', 400).fout);
  h.check('terwijl callen gewoon doorgaat', true, O.pokerAct(st, 0, 'call').ok);

  // En wie de kolom niet meekrijgt (een server van voor deze stap) mag gewoon verhogen.
  const st2 = { stoelen: [
    { stack: 900, inzet: 100, gefold: false, allin: false, gezet: true },
    { stack: 800, inzet: 200, gefold: false, allin: false, gezet: true },
  ], hoogste: 200, minVerhoging: 100, beurt: 0 };
  h.check('zonder die kolom verandert er niets', 300, O.pokerLegal(st2, 0).minRaise);
  h.check('en all-in kan nog steeds', 1000, O.pokerLegal(st2, 0).maxRaise);
}

process.exit(h.rapport('POKER'));
