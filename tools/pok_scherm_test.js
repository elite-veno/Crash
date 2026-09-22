// Tekent de pokertafel in elke fase die er in het spel voorkomt, met gegevens die eruit
// zien zoals de server ze stuurt, en kijkt of het scherm het overleeft en het juiste zegt.
//
// Alle andere toetsen hiernaast gaan over regels en over de database. Deze is de enige die
// zou merken dat het scherm klapt zodra er echt een hand op staat -- en hij vond meteen dat
// de fasebalk "SIT DOWN TO PLAY" zei terwijl je aan het spelen was.
//
//   npm install playwright          (chromium staat al op /opt/pw-browsers)
//   node tools/pok_scherm_test.js
//
// De browser wordt gezocht via PW_CHROMIUM, anders op de plek waar deze omgeving hem zet.
const pad = process.env.PW_NODE_MODULES || require('path').join(__dirname, '..', 'node_modules');
const { chromium } = require(pad + '/playwright');
const BROWSER = process.env.PW_CHROMIUM || '/opt/pw-browsers/chromium-1194/chrome-linux/chrome';

const UID = 'aaaaaaaa-0000-0000-0000-000000000001';
const commit = 'a'.repeat(64);

const stoel = (n, naam, uid, extra) => Object.assign({
  round_id: 1, seat_no: n, username: naam, user_id: uid, stack: 200, bet: 0, total_bet: 0,
  folded: false, allin: false, acted: false, payout: 0, shown: false,
  may_raise: true, card_commit: commit, hole: [],
}, extra || {});

const ronde = (extra) => Object.assign({
  id: 1, lobby_id: 1, started_at: new Date().toISOString(), street: 0, board: [],
  deck_commit: commit, board_commit: [commit, commit, commit, commit, commit],
  board_salt: null, button_seat: 0, sb: 5, bb: 10, high_bet: 10, min_raise: 10,
  to_act_seat: 0, act_seq: 0, act_deadline: new Date(Date.now() + 25000).toISOString(),
  settled_at: null, server_now: new Date().toISOString(),
}, extra || {});

const FASES = [
  { naam: 'geen tafel', round: null, seats: [], players: [], hole: [] },
  { naam: 'aan tafel, nog niet gedeeld', round: null, seats: [],
    players: [stoel(0, 'ann', UID), stoel(1, 'bob', 'b')], hole: [] },
  { naam: 'preflop, mijn beurt', round: ronde(),
    seats: [stoel(0, 'ann', UID, { bet: 5, total_bet: 5 }), stoel(1, 'bob', 'b', { bet: 10, total_bet: 10 })],
    players: [], hole: ['As', 'Ks'] },
  { naam: 'preflop, beurt van de ander', round: ronde({ to_act_seat: 1 }),
    seats: [stoel(0, 'ann', UID, { bet: 10, total_bet: 10, acted: true }), stoel(1, 'bob', 'b', { bet: 5, total_bet: 5 })],
    players: [], hole: ['As', 'Ks'] },
  { naam: 'flop met bord', round: ronde({ street: 1, board: ['2h', '7d', 'Tc'], high_bet: 0, to_act_seat: 0 }),
    seats: [stoel(0, 'ann', UID, { stack: 190, total_bet: 10 }), stoel(1, 'bob', 'b', { stack: 190, total_bet: 10 })],
    players: [], hole: ['As', 'Ks'] },
  { naam: 'korte all-in: geen raise meer', round: ronde({ street: 2, board: ['2h', '7d', 'Tc', '9s'], high_bet: 50 }),
    seats: [stoel(0, 'ann', UID, { bet: 20, may_raise: false, acted: true }),
            stoel(1, 'bob', 'b', { bet: 50, allin: true, stack: 0 })],
    players: [], hole: ['As', 'Ks'] },
  { naam: 'ik ben gepast', round: ronde({ to_act_seat: 1 }),
    seats: [stoel(0, 'ann', UID, { folded: true }), stoel(1, 'bob', 'b')],
    players: [], hole: ['As', 'Ks'] },
  { naam: 'ik ben blut', round: null, seats: [],
    players: [stoel(0, 'ann', UID, { stack: 0 }), stoel(1, 'bob', 'b')], hole: [] },
  { naam: 'showdown afgerekend', round: ronde({ street: 5, board: ['2h', '7d', 'Tc', '9s', 'Qd'],
      to_act_seat: null, act_deadline: null, settled_at: new Date().toISOString(),
      board_salt: ['s1', 's2', 's3', 's4', 's5'] }),
    seats: [stoel(0, 'ann', UID, { shown: true, hole: ['As', 'Ks'], payout: 40, stack: 220 }),
            stoel(1, 'bob', 'b', { shown: true, hole: ['2c', '3c'], stack: 180 })],
    players: [], hole: [] },
  { naam: 'zes spelers', round: ronde({ street: 3, board: ['2h', '7d', 'Tc', '9s', 'Qd'] }),
    seats: [0,1,2,3,4,5].map(i => stoel(i, 'speler' + i, i === 0 ? UID : 'x' + i,
      { folded: i % 3 === 0 && i > 0, allin: i === 2, stack: i * 40 })),
    players: [], hole: ['As', 'Ks'] },
];

(async () => {
  const b = await chromium.launch({ executablePath: BROWSER });
  const p = await b.newPage();
  const fouten = [];
  p.on('pageerror', e => fouten.push('pageerror: ' + e.message));
  await p.goto('file:///home/user/Crash/crash.html');
  await p.waitForTimeout(1200);
  await p.evaluate(() => { navigate('poker'); });
  await p.waitForTimeout(400);

  let stuk = 0;
  for (const f of FASES) {
    const uit = await p.evaluate(({ f, UID }) => {
      try {
        // Doen alsof er iemand is ingelogd en aan een tafel zit.
        AUTH.session = { userId: UID, username: 'ann' };
        LOBBY.id = 1; LOBBY.code = 'TEST'; LOBBY.members = [{ username: 'ann', host: true }];
        POK.round = f.round; POK.seats = f.seats; POK.hole = f.hole;
        // pk_table komt bij ELKE poll mee, ook tijdens een hand -- zie pokPull(). Een
        // opzet waarin POK.players leeg is tijdens een hand bestaat in het echt niet.
        POK.players = f.players.length ? f.players
          : f.seats.map(s => ({ lobby_id: 1, user_id: s.user_id, username: s.username,
                                seat_no: s.seat_no, stack: s.stack }));
        POK.zout = null; POK.bewijs = ''; POK.bord = ''; POK.error = '';
        pokRender();
        const acties = document.getElementById('pkActions');
        return {
          ok: true,
          stoelen: document.querySelectorAll('#pkSeats .pk-seat').length,
          fase: (document.getElementById('pkPhase') || {}).textContent || '',
          knoppen: acties && !acties.hidden,
          raise: !(document.getElementById('pkRaiseBtn') || {}).disabled,
          zit: (document.getElementById('pkSitBtn') || {}).textContent,
          eerlijk: (document.getElementById('pkFair') || {}).hidden
            ? '(verborgen)' : (document.getElementById('pkFair') || {}).textContent,
        };
      } catch (e) { return { ok: false, fout: String(e && e.message) }; }
    }, { f, UID });
    if (!uit.ok) { stuk++; console.log('KLAPT  ' + f.naam + ' -- ' + uit.fout); continue; }
    console.log('ok     ' + f.naam.padEnd(30) +
      ' stoelen=' + uit.stoelen + ' knoppen=' + (uit.knoppen ? 'ja' : 'nee') +
      ' raise=' + (uit.raise ? 'ja' : 'nee') + ' | ' + uit.fase);
    console.log('       ' + uit.eerlijk);
  }
  console.log('\nfasen die klappen: ' + stuk);
  console.log('paginafouten: ' + (fouten.length ? fouten.join(' | ') : 'geen'));
  await b.close();
  process.exit(stuk ? 1 : 0);
})();
