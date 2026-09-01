const http = require('http');

const PORT = process.env.PORT || 3000;

const server = http.createServer((req, res) => {
  if (req.url === '/health') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ status: 'ok' }));
    return;
  }

  res.writeHead(200, { 'Content-Type': 'application/json' });
  res.end(JSON.stringify({
    name: 'api-backend',
    status: 'running',
    message: 'API backend ready'
  }));
});

server.listen(PORT, '0.0.0.0', () => {
  console.log(`API listening on port ${PORT}`);
});
