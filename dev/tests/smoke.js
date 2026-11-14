// Smoke test: opens the site (with a fake Supabase from mock.js) and the Claude notebook version
// on a phone and a desktop, and walks the main paths. Needs Node + Playwright with Chromium.
//
//   node dev/tests/smoke.js
//
// Exit code 0 = all checks passed.
const fs = require('fs'), path = require('path');
const { chromium, devices } = require('playwright');
const DIR = __dirname, SRC = path.join(DIR, '..', 'src'), DATA = path.join(DIR, 'data'), TMP = path.join(DIR, '.tmp');
fs.mkdirSync(TMP, { recursive: true });

// site page with the mock in front of the app script
const site = fs.readFileSync(path.join(SRC, 'site.html'), 'utf8').split('\n');
site.splice(14, 0, '<script src="../mock.js"></script>');
fs.writeFileSync(path.join(TMP, 'site.html'),
  site.join('\n').replace("  supabaseUrl:'',\n  supabaseAnonKey:''", "  supabaseUrl:'https://x.supabase.co',\n  supabaseAnonKey:'k'"));
fs.copyFileSync(path.join(SRC, 'notebook.html'), path.join(TMP, 'notebook.html'));

let fails = 0;
const ok = (cond, msg) => { console.log((cond ? '  ok   ' : '  FAIL ') + msg); if (!cond) fails++; };
const init = () => { localStorage.setItem('mdb', JSON.stringify({ entries: [] })); localStorage.setItem('sn-form-mode', 'full');
  sessionStorage.setItem('ms', JSON.stringify({ user: { id: 'u-a', email: 'a@example.com' } })); };

(async () => {
  const b = await chromium.launch();
  for (const [page, label] of [['site.html', 'site'], ['notebook.html', 'notebook']]) {
    for (const [dname, dev] of [['phone', devices['iPhone 13']], ['desktop', { viewport: { width: 1280, height: 900 } }]]) {
      console.log(label + ' / ' + dname);
      const ctx = await b.newContext(dev), p = await ctx.newPage(), errs = [];
      p.on('pageerror', e => errs.push(e.message));
      await p.addInitScript(init);
      await p.goto('file://' + path.join(TMP, page)); await p.waitForTimeout(3000);
      ok(await p.$('#quickMore'), 'page loads');
      await p.click('#quickMore'); await p.waitForTimeout(400);
      ok(await p.evaluate(() => document.getElementById('dlg').open), 'new entry form opens');
      for (const f of ['test.uddf', 'test.xml', 'test.fit']) {
        await p.setInputFiles('#eImportF', path.join(DATA, f)); await p.waitForTimeout(700);
        ok(await p.evaluate(() => !!document.getElementById('eDepth').value), 'import ' + f + ' fills depth');
      }
      const chip = await p.evaluate(() => !document.getElementById('eDlogX').hidden);
      ok(chip, 'watch-data chip shown after .fit import');
      await p.evaluate(() => { document.getElementById('eSpot').value = 'Test'; document.getElementById('entryForm').requestSubmit(); });
      await p.waitForTimeout(1000);
      ok(await p.evaluate(() => !document.getElementById('dlg').open), 'entry saves');
      if (chip) {
        await p.locator('[data-dlog]').first().click(); await p.waitForTimeout(600);
        const n = await p.evaluate(() => document.querySelectorAll('#dlogBody figure').length);
        ok(n > 5, 'charts grid opens (' + n + ' charts)');
        await p.click('#dlogBody figure[data-k="0"] figcaption'); await p.waitForTimeout(300);
        ok(await p.evaluate(() => !!document.querySelector('.dl1t')), 'single chart opens');
        await p.click('#dlogBody [data-go][data-d="1"]'); await p.waitForTimeout(300);
        ok(await p.evaluate(() => document.querySelector('.dl1n b').textContent.startsWith('2')), 'next chart');
        await p.click('#dlogClose');
      }
      ok(errs.length === 0, 'no page errors' + (errs.length ? ': ' + errs.join(' | ') : ''));
      await ctx.close();
    }
  }
  await b.close();
  console.log(fails ? fails + ' check(s) failed' : 'all checks passed');
  process.exit(fails ? 1 : 0);
})();
