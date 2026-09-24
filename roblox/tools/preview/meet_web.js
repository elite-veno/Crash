// Meet de webversie op: waar staat elk blok, hoe hoog is het, en wat zegt de CSS erover.
// De tekening van de port is met tools/preview/meet_rbx.py op dezelfde manier op te meten,
// en dan zijn de twee getal voor getal naast elkaar te leggen -- zonder Studio en zonder
// te hoeven gissen waar het verschil vandaan komt.
//
//   node meet_web.js <scherm> [css-kiezer ...]
//
// Zonder kiezers pakt hij de blokken die op elk scherm staan. Elke kiezer wordt binnen het
// actieve scherm gezocht; `*` erachter geeft de kinderen.
const { chromium } = require('/opt/node22/lib/node_modules/playwright');
const BREED = 1536, HOOG = 1000;

const STANDAARD = ['.game-aside > *', '.board > *', '.panel > *', '.home-hero > *'];

(async () => {
  const scherm = process.argv[2];
  const kiezers = process.argv.slice(3);
  if (!scherm) { console.error('gebruik: node meet_web.js <scherm> [kiezer ...]'); process.exit(2); }

  const browser = await chromium.launch();
  const p = await browser.newPage({ viewport: { width: BREED, height: HOOG } });
  p.on('console', m => console.log(m.text()));
  await p.goto('file:///home/user/Crash/crash.html', { waitUntil: 'domcontentloaded' });
  await p.waitForTimeout(2500);
  const offline = p.locator('text=PLAY OFFLINE').first();
  if (await offline.count()) { await offline.click(); await p.waitForTimeout(2500); }

  // Dezelfde stand als scratchpad/webshot.js neemt: zijbalk dicht, één naam in de
  // accountbalk, en de pagina denkt dat hij verbonden is -- want in Roblox is de speler
  // altijd met de server verbonden en staat de seizoenstrip er gewoon.
  await p.evaluate(() => {
    document.getElementById('sidebar')?.classList.remove('open');
    document.querySelectorAll('.js-acct-switch, .js-acct-logout').forEach(e => e.remove());
    document.querySelectorAll('.js-acct-name').forEach(e => { e.textContent = 'Speler'; });
    try {
      window.online = () => true;
      AUTH.session = Object.assign({}, AUTH.session || {}, {
        username: 'Speler', userId: 'preview', offline: false,
      });
      AUTH.expired = false;
      for (const f of ['seasonRender', 'lbRender', 'profRender', 'achRender']) {
        if (typeof window[f] === 'function') window[f]();
      }
    } catch (e) {}
  });

  // 777 en Ride the Bus zijn alleen met een pas te zien; de zone zelf juist zonder.
  await p.evaluate((s) => {
    const wil = s === 'slots' || s === 'bus';
    if (typeof VIP === 'object' && typeof seasonId === 'function') VIP.season = wil ? seasonId() : null;
    if (typeof vipRender === 'function') vipRender();
  }, scherm);
  await p.waitForTimeout(400);

  await p.evaluate((v) => {
    document.querySelectorAll('.view').forEach(x => x.classList.remove('active'));
    document.getElementById(v + 'View')?.classList.add('active');
    if (typeof resizeCanvas === 'function') resizeCanvas();
    if (typeof navigate === 'function') { try { navigate(v); } catch (e) {} }
  }, scherm);
  await p.waitForTimeout(1200);

  await p.evaluate(([v, kiezers]) => {
    const wortel = document.getElementById(v + 'View');
    if (!wortel) { console.log('geen scherm ' + v); return; }
    const regels = [];
    for (const k of kiezers) {
      let nodes;
      try { nodes = wortel.querySelectorAll(k); } catch (e) { console.log('slechte kiezer: ' + k); continue; }
      nodes.forEach((e, i) => {
        if (i > 30) return;
        const r = e.getBoundingClientRect();
        const cs = getComputedStyle(e);
        regels.push([
          (k + '#' + i).padEnd(28),
          (e.className || e.tagName).slice(0, 24).padEnd(25),
          'top=' + r.top.toFixed(1),
          'h=' + r.height.toFixed(1),
          'mb=' + cs.marginBottom,
          'pad=' + cs.paddingTop + '/' + cs.paddingBottom,
          'fs=' + cs.fontSize,
          'lh=' + cs.lineHeight,
          '«' + (e.textContent || '').trim().replace(/\s+/g, ' ').slice(0, 30) + '»',
        ].join(' '));
      });
    }
    console.log(regels.join('\n'));
  }, [scherm, kiezers.length ? kiezers : STANDAARD]);

  await browser.close();
})();
