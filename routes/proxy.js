'use strict';

const { config } = require('../services/config');
const vlc = require('../services/vlcService');

const VALID_MACHINES = ['A', 'B', 'C'];
const VALID_COMMANDS = ['launch', 'load', 'play', 'pause', 'stop', 'seek'];

const GROUP_MAP = {
  A:   ['A'],
  B:   ['B'],
  C:   ['C'],
  AB:  ['A', 'B'],
  BC:  ['B', 'C'],
  AC:  ['A', 'C'],
  ABC: ['A', 'B', 'C'],
};

// Resolve the base URL for a given machine ID
function machineUrl(id) {
  if (id === config.machineId) {
    return `http://127.0.0.1:${config.serverPort}`;
  }
  const w = config.workers[id];
  if (!w) return null;
  return `http://${w.host}:${w.port}`;
}

// Fetch with a timeout
async function fetchWithTimeout(url, options, timeoutMs = 5000) {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);
  try {
    return await fetch(url, { ...options, signal: controller.signal });
  } finally {
    clearTimeout(timer);
  }
}

// Proxy a single VLC command to one machine
async function proxyCommand(machineId, command, body) {
  const base = machineUrl(machineId);
  if (!base) return { ok: false, error: `Unknown machine: ${machineId}` };

  const url = `${base}/vlc/${command}`;
  const method = command === 'status' ? 'GET' : 'POST';

  try {
    const res = await fetchWithTimeout(url, {
      method,
      headers: { 'Content-Type': 'application/json' },
      body: method === 'POST' ? JSON.stringify(body) : undefined,
    });
    return await res.json();
  } catch (err) {
    if (err.name === 'AbortError') {
      return { ok: false, error: `Machine ${machineId} timed out` };
    }
    return { ok: false, error: `Machine ${machineId} unreachable: ${err.message}` };
  }
}

module.exports = [
  // Proxy to a single machine: POST /machines/:id/vlc/:command
  {
    method: ['GET', 'POST'],
    path: '/machines/{id}/vlc/{command}',
    handler: async (request, h) => {
      const { id, command } = request.params;

      if (!VALID_MACHINES.includes(id)) {
        return h.response({ ok: false, error: `Invalid machine ID "${id}". Must be A, B, or C.` }).code(400);
      }
      if (!VALID_COMMANDS.includes(command) && command !== 'status') {
        return h.response({ ok: false, error: `Invalid command "${command}"` }).code(400);
      }

      const result = await proxyCommand(id, command, request.payload || {});
      return h.response(result).code(result.ok ? 200 : 502);
    },
  },

  // Fan-out to a group: POST /groups/:group/vlc/:command
  {
    method: 'POST',
    path: '/groups/{group}/vlc/{command}',
    handler: async (request, h) => {
      const { group, command } = request.params;

      const machines = GROUP_MAP[group];
      if (!machines) {
        return h.response({
          ok: false,
          error: `Invalid group "${group}". Valid groups: ${Object.keys(GROUP_MAP).join(', ')}`,
        }).code(400);
      }
      if (!VALID_COMMANDS.includes(command)) {
        return h.response({ ok: false, error: `Invalid command "${command}"` }).code(400);
      }

      const body = request.payload || {};

      // Fire all machine commands in parallel (best-effort)
      const settled = await Promise.allSettled(
        machines.map((id) => proxyCommand(id, command, body))
      );

      const results = {};
      let allOk = true;
      machines.forEach((id, i) => {
        const s = settled[i];
        if (s.status === 'fulfilled') {
          results[id] = s.value;
          if (!s.value.ok) allOk = false;
        } else {
          results[id] = { ok: false, error: s.reason?.message || 'Unknown error' };
          allOk = false;
        }
      });

      return h.response({ ok: allOk, results }).code(200);
    },
  },
];
