'use strict';

const path = require('path');
const { config, cues } = require('../services/config');

const publicDir = path.join(__dirname, '..', 'public');

module.exports = [
  // Serve the main web UI
  {
    method: 'GET',
    path: '/',
    handler: (request, h) => h.file(path.join(publicDir, 'index.html')),
  },

  // Serve static assets (CSS, JS)
  {
    method: 'GET',
    path: '/public/{param*}',
    handler: {
      directory: {
        path: publicDir,
        listing: false,
      },
    },
  },

  // Config + cues endpoint consumed by the browser UI
  {
    method: 'GET',
    path: '/api/config',
    handler: (request, h) => {
      return h.response({
        machineId: config.machineId,
        machines: ['A', 'B', 'C'],
        workerLabels: {
          A: 'Projector A (Master)',
          B: 'Projector B',
          C: 'Screen C',
        },
        cues: cues.cues,
      });
    },
  },
];
