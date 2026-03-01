'use strict';

const vlc = require('../services/vlcService');

module.exports = [
  {
    method: 'POST',
    path: '/vlc/launch',
    handler: async (request, h) => {
      const result = await vlc.launchVlc();
      return h.response(result).code(result.ok ? 200 : 500);
    },
  },

  {
    method: 'POST',
    path: '/vlc/load',
    handler: async (request, h) => {
      const { file, loop } = request.payload || {};
      if (!file) {
        return h.response({ ok: false, error: '"file" is required' }).code(400);
      }
      if (loop !== undefined) {
        const loopResult = await vlc.setRepeat(!!loop);
        if (!loopResult.ok) return h.response(loopResult).code(500);
      }
      const result = await vlc.loadAndCue(file);
      return h.response(result).code(result.ok ? 200 : 500);
    },
  },

  {
    method: 'POST',
    path: '/vlc/play',
    handler: async (request, h) => {
      const { loop } = request.payload || {};
      if (loop !== undefined) {
        const loopResult = await vlc.setRepeat(!!loop);
        if (!loopResult.ok) return h.response(loopResult).code(500);
      }
      const result = await vlc.sendCommand('pl_play');
      return h.response(result).code(result.ok ? 200 : 500);
    },
  },

  {
    method: 'POST',
    path: '/vlc/pause',
    handler: async (request, h) => {
      const result = await vlc.sendCommand('pl_pause');
      return h.response(result).code(result.ok ? 200 : 500);
    },
  },

  {
    method: 'POST',
    path: '/vlc/stop',
    handler: async (request, h) => {
      const result = await vlc.sendCommand('pl_stop');
      return h.response(result).code(result.ok ? 200 : 500);
    },
  },

  {
    method: 'POST',
    path: '/vlc/seek',
    handler: async (request, h) => {
      const { time } = request.payload || {};
      if (time === undefined || time === null) {
        return h.response({ ok: false, error: '"time" (seconds) is required' }).code(400);
      }
      // VLC seek takes seconds as a string value
      const result = await vlc.sendCommand('seek', { val: String(Math.round(time)) });
      return h.response(result).code(result.ok ? 200 : 500);
    },
  },

  {
    method: 'GET',
    path: '/vlc/status',
    handler: async (request, h) => {
      // Always return 200 so the UI can render state even when VLC is offline
      const result = await vlc.getStatus();
      return h.response(result).code(200);
    },
  },
];
