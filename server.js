'use strict';

const Hapi = require('@hapi/hapi');
const Inert = require('@hapi/inert');
const { config } = require('./services/config');

async function start() {
  const server = Hapi.server({
    port: config.serverPort,
    host: '0.0.0.0', // listen on all interfaces so phone on WiFi can connect
    routes: {
      cors: { origin: ['*'] },
    },
  });

  await server.register(Inert);

  // VLC control routes — registered on every machine
  server.route(require('./routes/vlc'));

  // File sync routes — workers need the upload endpoint; master also gets the sync endpoint
  const { workerRoutes, masterRoutes } = require('./routes/files');
  server.route(workerRoutes);

  // Master-only routes
  if (config.role === 'master') {
    server.route(require('./routes/proxy'));
    server.route(require('./routes/ui'));
    server.route(masterRoutes);
  }

  // Log incoming commands (skip noisy status polls)
  server.events.on('response', (request) => {
    const skip = request.method === 'get' && request.path.endsWith('/status');
    if (skip) return;

    const status = request.response?.statusCode ?? '?';
    const p      = request.payload;
    const body   = p && typeof p === 'object' && !Buffer.isBuffer(p) && typeof p.pipe !== 'function' && Object.keys(p).length
      ? ' ' + JSON.stringify(p)
      : '';
    console.log(`[${new Date().toLocaleTimeString()}] ${request.method.toUpperCase()} ${request.path}${body} → ${status}`);
  });

  await server.start();
  console.log(`[Machine ${config.machineId}] ${config.role} server running on port ${config.serverPort}`);
  if (config.role === 'master') {
    console.log(`  Web UI: http://localhost:${config.serverPort}/`);
    console.log(`  Access from phone at: http://<this-machine-ip>:${config.serverPort}/`);
  }

  // Auto-start VLC if it's not already running
  const vlc = require('./services/vlcService');
  const status = await vlc.getStatus();
  if (status.ok) {
    console.log(`[Machine ${config.machineId}] VLC already running`);
  } else {
    console.log(`[Machine ${config.machineId}] Starting VLC...`);
    const result = await vlc.launchVlc();
    if (result.ok) {
      console.log(`[Machine ${config.machineId}] VLC started (pid ${result.pid})`);
    } else {
      console.warn(`[Machine ${config.machineId}] VLC auto-start failed: ${result.error}`);
    }
  }
}

start().catch((err) => {
  console.error('Failed to start server:', err);
  process.exit(1);
});
