// HTTP/1.1 keep-alive benchmark origin for OPENPPP2 soak/bench runs.
//
// Memory mode: readFileSync once, serve the same Buffer on every request.
// Fast and simple — ideal for tunnel connectivity/stability/error-rate
// validation, where per-request disk I/O is irrelevant noise.
//
// Why not the Python one: http.server.SimpleHTTPRequestHandler defaults to
// HTTP/1.0, which closes the connection after every response. The ppp HTTP
// forward proxy only parses the first request of a client connection, so an
// HTTP/1.0 origin hides that defect (the client is forced to reconnect and
// never exercises the reuse path). Node's http server keeps the connection
// alive by default, which is what real browsers/proxies do.
//
// Usage:  node http_server_node.js [port] [directory] [host]
// Defaults: port=9092, directory=/tmp, host=127.0.0.1
// Pass host=0.0.0.0 only on origin boxes that must be reachable from other
// machines (e.g. the dmit public test origin); keep the default on local
// testbeds so the origin never listens beyond loopback.

const http = require('http');
const fs = require('fs');
const path = require('path');

const port = Number.parseInt(process.argv[2] || '9092', 10);
const directory = process.argv[3] || '/tmp';
const host = process.argv[4] || '127.0.0.1';

// Lazy cache: first request for a file reads it from disk, all later requests
// hit the in-memory Buffer (zero disk I/O).
const cache = new Map();

const server = http.createServer((req, res) => {
  if (req.method !== 'GET' && req.method !== 'HEAD') {
    res.writeHead(405, { 'Content-Length': '0' });
    res.end();
    return;
  }

  const rel = decodeURIComponent((req.url || '/').split('?')[0]);
  const file = path.join(directory, path.normalize(rel).replace(/^(\.\.[\/\\])+/, ''));

  let body = cache.get(file);
  if (body === undefined) {
    try {
      body = fs.readFileSync(file);
      cache.set(file, body);
    } catch {
      res.writeHead(404, { 'Content-Length': '9' });
      res.end('not found');
      return;
    }
  }

  res.writeHead(200, {
    'Content-Type': 'application/octet-stream',
    'Content-Length': body.length,
  });
  if (req.method === 'HEAD') {
    res.end();
    return;
  }
  res.end(body);
});

// Aggressive keep-alive: the point of this origin is connection reuse.
server.keepAliveTimeout = 30000;
server.headersTimeout = 35000;
server.listen(port, host, () => {
  console.log('memory origin on ' + host + ':' + port + ' from ' + directory);
});
