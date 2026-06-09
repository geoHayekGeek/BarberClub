import http from 'node:http';
import https from 'node:https';
import { URL } from 'node:url';

const listenPort = Number.parseInt(process.env.PORT ?? '3000', 10);
const target = new URL(
  process.env.TARGET_BASE_URL ??
    'https://barberclub-production-d46a.up.railway.app',
);

const upstreamClient = target.protocol === 'https:' ? https : http;

function proxyHeaders(headers) {
  const forwarded = { ...headers };
  delete forwarded.host;
  delete forwarded.connection;
  delete forwarded['content-length'];
  return forwarded;
}

const server = http.createServer((req, res) => {
  const incomingUrl = new URL(req.url ?? '/', target);

  const upstreamRequest = upstreamClient.request(
    {
      protocol: target.protocol,
      hostname: target.hostname,
      port: target.port || (target.protocol === 'https:' ? 443 : 80),
      method: req.method,
      path: `${incomingUrl.pathname}${incomingUrl.search}`,
      headers: proxyHeaders(req.headers),
      timeout: 30000,
    },
    (upstreamResponse) => {
      res.writeHead(upstreamResponse.statusCode ?? 502, upstreamResponse.headers);
      upstreamResponse.pipe(res);
    },
  );

  upstreamRequest.on('timeout', () => {
    upstreamRequest.destroy(new Error('Proxy request timed out'));
  });

  upstreamRequest.on('error', (error) => {
    if (res.headersSent) {
      res.destroy(error);
      return;
    }

    res.statusCode = 502;
    res.setHeader('Content-Type', 'application/json; charset=utf-8');
    res.end(
      JSON.stringify({
        error: 'proxy_error',
        message: error.message,
        target: target.origin,
      }),
    );
  });

  req.pipe(upstreamRequest);
});

server.listen(listenPort, '0.0.0.0', () => {
  console.log(
    `[emulator-api-proxy] listening on http://0.0.0.0:${listenPort} -> ${target.origin}`,
  );
});

