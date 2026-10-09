// Scripted SSE server for tests-sse/SSEStreamTest.as. Run via ./run.sh.
const http = require('http');
const conns = {};   // path -> [{t, lastEventId, accept}]
const logs = [];
let done;
const finished = new Promise(r => done = r);
const sleep = ms => new Promise(r => setTimeout(r, ms));
const sse = res => res.writeHead(200, {'Content-Type': 'text/event-stream', 'Cache-Control': 'no-cache'});

const server = http.createServer(async (req, res) => {
  const url = new URL(req.url, 'http://x');
  if (url.pathname === '/log') {
    const m = url.searchParams.get('m');
    logs.push(m);
    res.end('ok');
    if (m === 'END') done();
    return;
  }
  const list = conns[url.pathname] = conns[url.pathname] || [];
  list.push({t: Date.now(), lastEventId: req.headers['last-event-id'] || null, accept: req.headers.accept});
  const n = list.length;
  switch (url.pathname) {
    case '/s1':
      sse(res);
      if (n === 1) {
        res.write(':ping\n\n');
        await sleep(100);
        const b = Buffer.from('id: 1\ndata: {"a":"\u00e9t\u00e9"}\n\n', 'utf8');
        const cut = b.indexOf(0xc3) + 1; // split inside a 2-byte UTF-8 char
        res.write(b.subarray(0, cut)); await sleep(150); res.write(b.subarray(cut));
        await sleep(100);
        res.write('event: reset\nid: 5\ndata: {"reason":"gap","oldest_available_id":5}\n\n');
        res.write('event: triominos.future\ndata: ignored\n\n');
        res.write('id: 6\r\ndata: line1\r\ndata: line2\r\n\r\n');
        await sleep(100);
        res.end(); // server closes -> client reconnects with Last-Event-ID
      } else if (n === 2) {
        res.write('id: 7\ndata: done\n\n'); // then silence -> watchdog trips
      } else {
        res.write(':ping\n\n');
      }
      return;
    case '/404': res.writeHead(404); res.end('{}'); return;
    case '/html': res.writeHead(200, {'Content-Type': 'text/html'}); res.end('<html></html>'); return;
    case '/hang': sse(res); return; // headers, no data ever
    case '/503': res.writeHead(503); res.end(); return;
  }
  res.writeHead(500); res.end();
});

server.listen(18765, '127.0.0.1', async () => {
  console.log('listening');
  const timeout = setTimeout(() => { console.log('TIMEOUT'); report(); }, 90000);
  await finished; clearTimeout(timeout); report();
});

function report() {
  let ok = true;
  const check = (name, cond) => { console.log((cond ? 'PASS ' : 'FAIL ') + name); ok = ok && cond; };
  const s1 = conns['/s1'] || [];
  console.log('logs:', JSON.stringify(logs, null, 1));
  console.log('conns:', JSON.stringify(conns, null, 1));
  check('Accept header sent', s1.length > 0 && s1[0].accept === 'text/event-stream');
  check('fresh connect has no Last-Event-ID', s1[0] && s1[0].lastEventId === null);
  check('utf-8 split across chunks', logs.includes('msg|null|1|{"a":"\u00e9t\u00e9"}'));
  check('reset event delivered', logs.includes('msg|reset|5|{"reason":"gap","oldest_available_id":5}'));
  check('unknown event passed up (filtered by caller)', logs.includes('msg|triominos.future|null|ignored'));
  check('CRLF + multi-line data', logs.includes('msg|null|6|line1\nline2'));
  check('reconnect sends Last-Event-ID', s1[1] && s1[1].lastEventId === '6');
  check('watchdog reconnect sends Last-Event-ID', s1[2] && s1[2].lastEventId === '7');
  check('ping-only stream is not a failure', !logs.some(l => l.startsWith('fail|s1')));
  check('404 -> fail after 1 attempt', logs.includes('fail|404|HTTP 404') && conns['/404'].length === 1);
  check('text/html -> fail', logs.some(l => l.startsWith('fail|html|Content-Type')) && conns['/html'].length === 1);
  check('silent stream -> fail after 3 attempts', logs.includes('fail|hang|3 attempts without data') && conns['/hang'].length === 3);
  check('503 -> retried then fail', logs.includes('fail|503|3 attempts without data') && conns['/503'].length === 3);
  const h = (conns['/503'] || []).map(c => c.t);
  if (h.length === 3) {
    const d1 = h[1] - h[0], d2 = h[2] - h[1];
    console.log('backoff delays', d1, d2);
    check('backoff 1: 750-1250ms (+/-25%)', d1 >= 700 && d1 <= 1400);
    check('backoff 2: 1500-2500ms (doubles)', d2 >= 1450 && d2 <= 2650);
  }
  console.log(ok ? 'ALL PASS' : 'SOME FAILED');
  process.exit(ok ? 0 : 1);
}
