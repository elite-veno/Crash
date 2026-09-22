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
// Een vervalst bord MET bijpassende hashes en zouten -- alsof de server alles opnieuw
// heeft uitgerekend op het moment van afrekenen.
const vals = ['As', 'Ah', 'Ad', 'Ac', 'Ks'];
const valsZout = vals.map((_, i) => 'vz' + i);
const valsHash = vals.map((k, i) => h(valsZout[i] + ':' + k));

// Elk geval is: wat de server bij het DELEN stuurde, en wat hij bij het AFREKENEN stuurt.
// Dat onderscheid is het hele punt -- de vorige versie vergeleek één antwoord met zichzelf,
// en een server die bij het afrekenen bord en hashes samen herrekende kwam er met een
// groen vinkje doorheen.
const GEVALLEN = [
  { naam: 'alles klopt', deal: { hash: bordHash }, af: { bord, zout: bordZout, hash: bordHash },
    commit: h(zout + ':' + hand[0] + hand[1]), wacht: 'match the hashes stored before the flop' },

  { naam: 'bord vervalst, hashes van de deal', deal: { hash: bordHash },
    af: { bord: ['As', 'Ah', 'Ad', 'Ac', 'Ks'], zout: bordZout, hash: bordHash },
    commit: h(zout + ':' + hand[0] + hand[1]), wacht: 'does NOT match' },

  // DE AANVAL DIE ERDOORHEEN KWAM. De server gooit het bord om en rekent de hashes en de
  // zouten er meteen bij opnieuw uit. Alles binnen dat ene antwoord klopt met zichzelf.
  { naam: 'bord + hashes samen herrekend', deal: { hash: bordHash },
    af: { bord: vals, zout: valsZout, hash: valsHash },
    commit: h(zout + ':' + hand[0] + hand[1]), wacht: 'does NOT match' },

  // En de realistische variant: tot en met de turn eerlijk, alleen de river geruild.
  { naam: 'alleen de river geruild', deal: { hash: bordHash },
    af: { bord: bord.slice(0, 4).concat(['Ah']), zout: bordZout.slice(0, 4).concat(['rz']),
          hash: bordHash.slice(0, 4).concat([h('rz:Ah')]) },
    commit: h(zout + ':' + hand[0] + hand[1]), wacht: 'does NOT match' },

  { naam: 'hand vervalst', deal: { hash: bordHash }, af: { bord, zout: bordZout, hash: bordHash },
    commit: h('anderzout:' + hand[0] + hand[1]), wacht: 'does NOT match' },

  { naam: 'geen hash bij de kaarten', deal: { hash: bordHash },
    af: { bord, zout: bordZout, hash: bordHash }, commit: null, wacht: 'does NOT match' },

  { naam: 'zout ontbreekt bij het afrekenen', deal: { hash: bordHash },
    af: { bord, zout: null, hash: bordHash },
    commit: h(zout + ':' + hand[0] + hand[1]), wacht: 'does NOT match' },

  { naam: 'hand loopt nog', deal: { hash: bordHash }, af: null,
    commit: h(zout + ':' + hand[0] + hand[1]), wacht: 'your hand matches its hash' },

  { naam: 'iedereen paste, geen bordkaart', deal: { hash: bordHash },
    af: { bord: [], zout: [], hash: bordHash },
    commit: h(zout + ':' + hand[0] + hand[1]), wacht: 'no board card was ever dealt' },

  // Pas na de flop binnengekomen: er is niets van voor de flop om tegenaan te rekenen, en
  // dan hoort er geen belofte over "voor de flop" te staan.
  { naam: 'pas na de flop binnengekomen', deal: null,
    af: { bord, zout: bordZout, hash: bordHash },
    commit: h(zout + ':' + hand[0] + hand[1]), wacht: 'joined after the flop' },
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
      // Schoon beginnen: elk geval is een eigen hand, en er mag niets van het vorige
      // blijven plakken -- niet in POK en niet in localStorage.
      POK.vast = null; POK.bewijs = ''; POK.bord = ''; POK.bewijsVan = 0; POK.bewijsRonde = 0;
      try { localStorage.removeItem('crash_pk_vast'); } catch (e) {}

      const stoel = (commit) => [{ round_id: 1, seat_no: 0, username: 'ann', user_id: UID,
        stack: 200, bet: 0, total_bet: 0, folded: false, allin: false, acted: false,
        payout: 0, shown: false, may_raise: true, card_commit: commit, hole: [] }];
      POK.players = [{ user_id: UID, username: 'ann', seat_no: 0, stack: 200 }];

      // EERST de poll van bij het delen: bord leeg, zouten nog dicht, hashes er al. Dit is
      // het moment waarop de browser hoort vast te pinnen.
      if (g.deal) {
        POK.round = { id: 1, lobby_id: 1, street: 0, board: [], deck_commit: 'a'.repeat(64),
          board_commit: g.deal.hash, board_salt: null, settled_at: null,
          to_act_seat: 0, high_bet: 10, min_raise: 10, act_seq: 0 };
        POK.seats = stoel(g.commit);
        POK.hole = hand;
        POK.zout = { salt: zout, seat: 0, kaarten: hand };
        await pokEerlijk();
      }

      // DAN de poll van bij het afrekenen -- eventueel met heel andere gegevens.
      if (g.af) {
        POK.round = { id: 1, lobby_id: 1, street: 5, board: g.af.bord,
          deck_commit: 'a'.repeat(64), board_commit: g.af.hash, board_salt: g.af.zout,
          settled_at: new Date().toISOString(),
          to_act_seat: null, high_bet: 0, min_raise: 10, act_seq: 0 };
        POK.seats = stoel(g.commit);
        POK.hole = [];
        POK.zout = g.deal ? null : { salt: zout, seat: 0, kaarten: hand };
        await pokEerlijk();
      }
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
