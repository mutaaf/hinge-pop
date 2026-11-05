// Local server for `npm run up`. Serves dist/ at the same path as production.
import { createServer } from 'node:http';
import { readFile } from 'node:fs/promises';

const port = Number(process.env.PORT || 8796);
createServer(async (req, res) => {
  const path = new URL(req.url, 'http://localhost').pathname;
  if (path === '/' || path === '/hingepop') {
    res.writeHead(302, { Location: '/hingepop/' }).end();
    return;
  }
  if (path !== '/hingepop/' && path !== '/hingepop/index.html') {
    res.writeHead(404).end('Not found');
    return;
  }
  res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8', 'Cache-Control': 'no-store' });
  res.end(await readFile('dist/hingepop/index.html'));
}).listen(port, () => console.log(`Hinge Pop: http://localhost:${port}/hingepop/`));
