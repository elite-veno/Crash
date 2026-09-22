// De wiskunde van elk spel op de pagina, getoetst zonder browser.
//   node tools/odds_test.js
//
// Waarom dit er is: `const ODDS` in crash.html zegt van zichzelf "pure, testable", maar er
// stond niets dat het ook deed. Elke uitbetaling in het casino komt hier vandaan, dus een
// rekenfout is geld -- en bij poker, waar spelers tegen elkaar spelen in plaats van tegen
// het huis, is een fout in de handbeoordelaar meteen iemands pot.
const { lees } = require('./odds.js');
const h = require('./harness.js');

const O = lees();

// ---------- crash ----------
// P(crash >= M) = 0.97 / M, dus de laagste trekking geeft precies het huisvoordeel terug.
h.check('crash begint bij 1.00', 1, O.crashPoint(0));
h.bijna('crash bij de helft', 1.94, O.crashPoint(0.5), 0.005);
h.check('crash loopt niet boven de duizend', 1000, O.crashPoint(0.999999999));
{
  // P(crash > M) = 0.97/M. Let op het groter-dan: crashPoint rondt naar BOVEN af op
  // centen, juist zodat die wet op de cent klopt voor elk doel met twee decimalen. Met
  // >= zou je 1.99 meetellen als 2x, en dan komt er iets meer uit.
  // Niet met toeval getoetst maar met een vast rooster over (0,1).
  const N = 200000;
  const deel = (M, streng) => {
    let raak = 0;
    for (let i = 0; i < N; i++) {
      const c = O.crashPoint((i + 0.5) / N);
      if (streng ? c > M : c >= M) raak++;
    }
    return raak / N;
  };
  h.bijna('0.97/2 van de vluchten komt boven 2x', 0.485, deel(2, true), 0.001);
  h.bijna('0.97/10 komt boven 10x', 0.097, deel(10, true), 0.001);
  h.bijna('0.97/1.5 komt boven 1.5x', 0.97 / 1.5, deel(1.5, true), 0.001);
  // En het spiegelbeeld: ongeveer drie op de honderd rondes knallen meteen op 1.00.
  h.bijna('drie procent knalt bij 1.00', 0.03, 1 - deel(1, true), 0.001);
}

// ---------- roulette ----------
h.check('nul is groen', 'green', O.rouletteColor(0));
h.check('een is rood', 'red', O.rouletteColor(1));
h.check('twee is zwart', 'black', O.rouletteColor(2));
h.check('een vol nummer betaalt 36 keer', 36, O.roulettePayout('n:17', 17));
h.check('en niets als het mis is', 0, O.roulettePayout('n:17', 18));
h.check('rood op rood betaalt dubbel', 2, O.roulettePayout('red', 1));
h.check('nul slaat alles behalve het nummer zelf', 0, O.roulettePayout('red', 0));
h.check('het wiel heeft 37 vakjes', 37, O.ROULETTE_ORDER.length);
h.check('en achttien rode', 18, O.ROULETTE_RED.size);
{
  // Het huisvoordeel van roulette is 1/37: over alle 37 uitkomsten keert rood 36/37 uit.
  let som = 0;
  for (const n of O.ROULETTE_ORDER) som += O.roulettePayout('red', n);
  h.bijna('rood keert 36 van de 37 uit', 36 / 37, som / 37 / 1, 1e-9);
}

// ---------- toren ----------
// Elke vermenigvuldiger wordt naar beneden op centen afgerond -- uitbetalingen gaan hier
// altijd naar beneden, nooit naar boven. Dus de verwachte waarde is die afronding.
const omlaag = x => Math.floor(x * 100 + 1e-9) / 100;
for (const [naam, d] of Object.entries(O.TOWER_DIFF)) {
  h.check('toren ' + naam + ': één verdieping is 0.97 x tegels/veilig',
    omlaag(0.97 * d.tiles / d.safe), O.towerMultiplier(naam, 1));
}
h.waar('negen verdiepingen op master is een grote vermenigvuldiger',
  O.towerMultiplier('master', 9) > 1000);

// ---------- mijnen ----------
h.check('mijnen heeft 25 tegels', 25, O.MINES_TILES);
h.check('één veilige tegel met één mijn', omlaag(0.97 * 25 / 24), O.minesMultiplier(1, 1));
h.waar('meer mijnen betaalt meer', O.minesMultiplier(5, 3) > O.minesMultiplier(3, 3));

// ---------- plinko ----------
for (const rijen of [8, 12, 16]) {
  for (const risico of ['low', 'medium', 'high']) {
    // De tabel wordt op centen afgerond en daarna symmetrisch gemaakt, dus 97% komt er
    // niet tot op de komma uit; een halve cent speling is wat de afronding kan schelen.
    h.bijna('plinko ' + rijen + '/' + risico + ' keert 97% uit',
      0.97, O.plinkoRtp(rijen, O.plinkoTable(rijen, risico)), 0.005);
  }
}
h.check('acht rijen geeft negen bakjes', 9, O.plinkoTable(8, 'low').length);

// ---------- paarden ----------
{
  const veld = O.horseField();
  h.check('zes paarden', 6, veld.length);
  const som = veld.reduce((a, b) => a + b, 0);
  h.bijna('de kansen tellen op tot één', 1, som, 0.0001);
  for (const p of veld) {
    h.check('uitbetaling is 0.97 gedeeld door de kans', omlaag(0.97 / p), O.horseMultiplier(p));
  }
}

// ---------- krasloten en 777 ----------
h.bijna('krasloten keren 97% uit', 0.97, O.scratchRtp(), 0.0005);
h.bijna('777 keert 97% uit', 0.97, O.slotRtp(), 0.0005);
h.bijna('het rad keert 97% uit', 0.97, O.wheelRtp(), 0.0005);

// ---------- ride the bus ----------
h.check('de bus heeft vier stappen', 4, O.BUS_STEPS.length);
{
  const pak = [];
  for (const s of O.BUS_SUITS) for (const r of O.BUS_RANKS) pak.push({ r, s });
  h.check('een vol pak is tweeënvijftig kaarten', 52, pak.length);
  // Stap 0 is rood of zwart: precies de helft.
  h.bijna('rood of zwart is fiftyfifty', 0.5, O.busChance(pak, 0, 'red', []), 1e-9);
  // Stap 1 is hoger of lager dan de kaart die er ligt; gelijk verliest altijd. Ligt er een
  // zeven, dan zijn er 24 hogere kaarten in de 51 die over zijn.
  const zonderZeven = pak.filter(c => c.r !== '7' || c.s !== '♠');
  h.bijna('hoger dan zeven uit 51 kaarten', 24 / 51,
    O.busChance(zonderZeven, 1, 'higher', [{ r: '7', s: '♠' }]), 1e-9);
  // Stap 3 is de kleur: dertien van elke soort.
  h.bijna('de goede soort is een op vier', 13 / 52, O.busChance(pak, 3, '♠', []), 1e-9);
  // En de uitbetaling is 0.97 gedeeld door de kans, naar beneden afgerond.
  h.check('de bus betaalt 0.97 gedeeld door de kans', omlaag(0.97 / 0.5), O.busMultiplier(0.5));
  h.check('een kans van nul betaalt niets', 0, O.busMultiplier(0));
}

// ---------- blackjack ----------
// Een kaart is { r, s }, en bjValue geeft de waarde plus of hij zacht is.
const k = (r, s = '♠') => ({ r, s });
h.check('een aas en een tien is 21', { total: 21, soft: true }, O.bjValue([k('A'), k('10')]));
h.check('en dat is blackjack', true, O.bjIsBlackjack([k('A'), k('10')]));
h.check('drie kaarten van 21 is geen blackjack', false,
  O.bjIsBlackjack([k('7'), k('7'), k('7')]));
h.check('twee azen zijn twaalf', { total: 12, soft: true }, O.bjValue([k('A'), k('A')]));
h.check('een zachte hand die hard wordt', { total: 16, soft: false },
  O.bjValue([k('A'), k('5'), k('10')]));
h.check('een volle schoen is zes pakken', 312, O.bjNewShoe().length);
{
  // De dealer pakt tot 17 en blijft staan op zachte 17.
  const hand = [k('A'), k('6')];
  O.bjDealerPlay(hand, () => k('2'));
  h.check('zachte zeventien blijft staan', 17, O.bjValue(hand).total);
}
// bjSettle krijgt de twee handen, niet hun waarde.
h.check('gelijk spel geeft de inzet terug', 1, O.bjSettle([k('10'), k('10')], [k('10'), k('10')]));
h.check('doorgeslagen speler krijgt niets', 0,
  O.bjSettle([k('10'), k('10'), k('5')], [k('10'), k('9')]));
h.check('doorgeslagen dealer betaalt', 2,
  O.bjSettle([k('10'), k('9')], [k('10'), k('10'), k('5')]));
h.check('blackjack betaalt anderhalf keer', 2.5, O.bjSettle([k('A'), k('K')], [k('10'), k('9')]));
h.check('blackjack tegen blackjack is push', 1, O.bjSettle([k('A'), k('K')], [k('A'), k('Q')]));
h.check('de dealer met blackjack wint van 21 in drie', 0,
  O.bjSettle([k('7'), k('7'), k('7')], [k('A'), k('Q')]));

process.exit(h.rapport('ODDS'));
