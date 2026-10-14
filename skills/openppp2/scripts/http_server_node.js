// HTTP/1.1 keep-alive benchmark origin for OPENPPP2 soak/bench runs.
//
// Why not the Python one: http.server.SimpleHTTPRequestHandler defaults to
// HTTP/1.0, which closes the connection after every response. The ppp HTTP
// forward proxy only parses the first request of a client connection, so an
// HTTP/1.0 origin hides that defect (the client is forced to reconnect and
// never exercises the reuse path). Node's http server keeps the connection
// alive by default, which is what real browsers/proxies do.
//
// Usage:  node http_server_node.js [port] [directory]
// Defaults: port=9092, directory=/tmp
// Serves files with an accurate Content-Length and Connection: keep-alive.

const http = require('http');
const fs = require('fs');
const path = require('path');

const port = Number.parseInt(process.argv[2] || '9092', 10);
const directory = process.argv[3] || '/tmp';

const server = http.createServer((req, res) => {
  if (req.method !== 'GET' && req.method !== 'HEAD') {
    res.writeHead(405, { 'Content-Length': '0' });
    res.end();
    return;
  }

  const rel = decodeURIComponent((req.url || '/').split('?')[0]);
  const file = path.join(directory, path.normalize(rel).replace(/^(\.\.[\/\\])+/, ''));
  fs.stat(file, (err, st) => {
    if (err || !st.isFile()) {
      res.writeHead(404, { 'Content-Length': '9' });
      res.end('not found');
      return;
    }

    res.writeHead(200, { 'Content-Type': 'application/octet-stream', 'Content-Length': st.size });
    if (req.method === 'HEAD') {
      res.end();
      return;
    }
    fs.createReadStream(file).pipe(res);
  });
});

// Aggressive keep-alive: the point of this origin is connection reuse.
server.keepAliveTimeout = 30000;
server.headersTimeout = 35000;
server.listen(port, '127.0.0.1', () => {
  console.log('keep-alive origin on 127.0.0.1:' + port + ' from ' + directory);
});
