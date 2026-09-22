// Toetst pokEerlijk() in een echte browser: klopt hij op echte hashes, ziet hij het als er
// met het bord of met een hand geknoeid is, en zegt hij dat hij niets kon controleren in
// plaats van iets geruststellends?
//
// Die laatste is waar het om begonnen was. De tekst zei ooit "hashed before the deal" en
// klonk het rustigst als er juist niets was nagerekend.
//
//   npm install playwright
//   node tools/pok_eerlijk_test.js
const pad = process.env.PW_NODE_MODULES || require('path').join(__dirname, '..', 'node_modules');
const { chromium } = require(pad + '/playwright');
const BROWSER = process.env.PW_CHROMIUM || '/opt/pw-browsers/chromium-1194/chrome-linux/chrome';

const c = require('crypto');
const h = t => c.createHash('sha256').update(t).digest('hex');

const UID = 'aaaaaaaa-0000-0000-0000-000000000001';
const zout = 'zzz';
const hand = ['As', 'Ks'];
const bord = ['2h', '7d', 'Tc', '9s', 'Qd'];
const bordZout = bord.map((_, i) => 'bz' + i);
const bordHash = bord.map((k, i) => h(bordZout[i] + ':' + k));

const GEVALLEN = [
  { naam: 'alles klopt', commit: h(zout + ':' + hand[0] + hand[1]), bord, bordZout, bordHash,
    wacht: 'your hand and the board match' },
  { naam: 'bord vervalst', commit: h(zout + ':' + hand[0] + hand[1]),
    bord: ['As', 'Ah', 'Ad', 'Ac', 'Ks'], bordZout, bordHash, wacht: 'does NOT match' },
  { naam: 'hand vervalst', commit: h('anderzout:' + hand[0] + hand[1]), bord, bordZout, bordHash,
    wacht: 'does NOT match' },
  { naam: 'geen hash bij de kaarten', commit: null, bord, bordZout, bordHash, wacht: 'does NOT match' },
  { naam: 'hand loopt nog, geen zouten', commit: h(zout + ':' + hand[0] + hand[1]),
    bord: [], bordZout: null, bordHash, wacht: 'your hand matches' },
];

(async () => {
  const b = await chromium.launch({ executablePath: BROWSER });
  const p = await b.newPage();
  await p.goto('file:///home/user/Crash/crash.html');
  await p.waitForTimeout(1200);
  await p.evaluate(() => navigate('poker'));
  let stuk = 0;
  for (const g of GEVALLEN) {
    const uit = await p.evaluate(async ({ g, UID, zout, hand }) => {
      AUTH.session = { userId: UID, username: 'ann' };
      LOBBY.id = 1;
      POK.round = {
        id: 1, lobby_id: 1, street: 5, board: g.bord, deck_commit: 'a'.repeat(64),
        board_commit: g.bordHash, board_salt: g.bordZout,
        settled_at: g.bordZout ? new Date().toISOString() : null,
        to_act_seat: null, high_bet: 0, min_raise: 10, act_seq: 0,
      };
      POK.seats = [{ round_id: 1, seat_no: 0, username: 'ann', user_id: UID, stack: 200,
                     bet: 0, total_bet: 0, folded: false, allin: false, acted: false,
                     payout: 0, shown: false, may_raise: true, card_commit: g.commit, hole: [] }];
      POK.players = [{ user_id: UID, username: 'ann', seat_no: 0, stack: 200 }];
      POK.hole = hand;
      POK.zout = { salt: zout, seat: 0, kaarten: hand };
      await pokEerlijk();
      pokRender();
      return { tekst: (document.getElementById('pkFair') || {}).textContent || '',
               bewijs: POK.bewijs, bord: POK.bord };
    }, { g, UID, zout, hand });
    const goed = uit.tekst.includes(g.wacht);
    if (!goed) stuk++;
    console.log((goed ? 'ok     ' : 'FOUT   ') + g.naam.padEnd(26) +
      ' hand=' + (uit.bewijs || '-') + ' bord=' + (uit.bord || '-'));
    console.log('       ' + uit.tekst.replace(/^Shuffle \S+ · /, ''));
  }
  console.log('\nmis: ' + stuk);
  await b.close();
  process.exit(stuk ? 1 : 0);
})();
