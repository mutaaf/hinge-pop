// Local server for `npm run up` and the landing tests. Serves dist/ at the same paths as production.
import { createServer } from 'node:http';
import { readFile, stat } from 'node:fs/promises';
import { extname, join, normalize } from 'node:path';

const TYPES = { '.html': 'text/html; charset=utf-8', '.css': 'text/css', '.js': 'text/javascript', '.json': 'application/json', '.webp': 'image/webp', '.jpg': 'image/jpeg', '.png': 'image/png', '.woff2': 'font/woff2', '.svg': 'image/svg+xml' };

export function serve(port = 8796, root = 'dist') {
  return new Promise((done) => {
    const server = createServer(async (req, res) => {
      const path = decodeURIComponent(new URL(req.url, 'http://localhost').pathname);
      if (path === '/') { res.writeHead(302, { Location: '/hingepop/' }).end(); return; }
      const file = join(root, normalize(path).replace(/^(\.\.[/\\])+/, ''));
      try {
        const info = await stat(file);
        if (info.isDirectory()) {
          if (!path.endsWith('/')) { res.writeHead(302, { Location: path + '/' }).end(); return; }
          res.writeHead(200, { 'Content-Type': TYPES['.html'], 'Cache-Control': 'no-store' });
          res.end(await readFile(join(file, 'index.html')));
          return;
        }
        res.writeHead(200, { 'Content-Type': TYPES[extname(file)] || 'application/octet-stream', 'Cache-Control': 'no-store' });
        res.end(await readFile(file));
      } catch {
        res.writeHead(404).end('Not found');
      }
    });
    server.listen(port, () => done(server));
  });
}

if (import.meta.url === `file://${process.argv[1]}`) {
  const port = Number(process.env.PORT || 8796);
  await serve(port);
  console.log(`Hinge Pop: http://localhost:${port}/hingepop/`);
}
