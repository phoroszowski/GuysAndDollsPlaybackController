'use strict';

const { spawn } = require('child_process');
const path = require('path');
const { config } = require('./config');

const vlcCfg = config.vlc;
let vlcProcess = null;

// Build Basic auth header for VLC HTTP API (empty username, password only)
const authHeader = 'Basic ' + Buffer.from(':' + vlcCfg.httpPassword).toString('base64');
const vlcBaseUrl = `http://${vlcCfg.httpHost}:${vlcCfg.httpPort}`;

/**
 * Launch VLC with the HTTP interface enabled.
 * Resolves after a short delay to allow VLC to start listening.
 */
async function launchVlc() {
  if (vlcProcess && !vlcProcess.killed) {
    return { ok: true, pid: vlcProcess.pid, note: 'already running' };
  }

  const args = [
    '--extraintf', 'http',
    '--http-host', '0.0.0.0',
    '--http-port', String(vlcCfg.httpPort),
    '--http-password', vlcCfg.httpPassword,
    '--no-video-title-show',
    '--fullscreen',
  ];

  if (vlcCfg.screenNumber !== undefined) {
    args.push(`--qt-fullscreen-screennumber=${vlcCfg.screenNumber}`);
  }

  vlcProcess = spawn(vlcCfg.executablePath, args, {
    detached: false,
    stdio: 'ignore',
  });

  vlcProcess.on('exit', (code) => {
    console.log(`VLC exited with code ${code}`);
    vlcProcess = null;
  });

  // Give VLC time to start its HTTP server
  await new Promise((resolve) => setTimeout(resolve, 1500));

  return { ok: true, pid: vlcProcess.pid };
}

/**
 * Send a command to VLC's HTTP API.
 * @param {string} command - VLC command (e.g. 'pl_play', 'pl_pause', 'pl_stop', 'seek', 'in_play')
 * @param {Object} params - Additional query parameters (e.g. { input: 'file:///...' })
 */
async function sendCommand(command, params = {}) {
  const qs = new URLSearchParams({ command, ...params });
  const url = `${vlcBaseUrl}/requests/status.json?${qs}`;

  try {
    const res = await fetchWithTimeout(url, {
      headers: { Authorization: authHeader },
    }, 3000);

    if (res.status === 401) {
      return { ok: false, error: 'VLC auth failed — check httpPassword in config.json' };
    }
    if (!res.ok) {
      return { ok: false, error: `VLC HTTP error: ${res.status}` };
    }

    const data = await res.json();
    return { ok: true, state: data.state };
  } catch (err) {
    if (err.name === 'AbortError') {
      return { ok: false, error: 'VLC request timed out' };
    }
    return { ok: false, error: `VLC not responding: ${err.message}` };
  }
}

/**
 * Get current VLC playback status.
 */
async function getStatus() {
  const url = `${vlcBaseUrl}/requests/status.json`;

  try {
    const res = await fetchWithTimeout(url, {
      headers: { Authorization: authHeader },
    }, 3000);

    if (res.status === 401) {
      return { ok: false, error: 'VLC auth failed' };
    }
    if (!res.ok) {
      return { ok: false, error: `VLC HTTP error: ${res.status}` };
    }

    const data = await res.json();

    // Extract filename from the information block if available
    let filename = '';
    if (data.information && data.information.category && data.information.category.meta) {
      filename = data.information.category.meta.filename || '';
    }

    return {
      ok: true,
      state: data.state,       // 'playing', 'paused', 'stopped'
      filename,
      time: data.time || 0,    // seconds elapsed
      length: data.length || 0, // total duration seconds
      position: data.position || 0, // 0.0 to 1.0
      repeat: !!data.repeat,   // single-item loop on/off
    };
  } catch (err) {
    if (err.name === 'AbortError') {
      return { ok: false, error: 'VLC request timed out' };
    }
    return { ok: false, error: `VLC not responding: ${err.message}` };
  }
}

/**
 * Build a file:/// URI from a filename, resolving against videoDirectory.
 * VLC requires forward slashes even on Windows.
 */
function buildFileUri(filename) {
  const fullPath = path.join(vlcCfg.videoDirectory, filename);
  // Convert Windows backslashes to forward slashes for file URI
  const uriPath = fullPath.replace(/\\/g, '/');
  return `file:///${uriPath}`;
}

/**
 * Set VLC single-item repeat (loop) on or off.
 * Reads current state first and only sends the toggle if it needs to change.
 */
async function setRepeat(enabled) {
  const status = await getStatus();
  if (!status.ok) return status;
  if (status.repeat !== enabled) {
    return sendCommand('pl_repeat');
  }
  return { ok: true };
}

/**
 * Load a video file and pause on the first frame.
 * This "cues" the video so it's ready to play on demand.
 */
async function loadAndCue(filename) {
  const uri = buildFileUri(filename);
  const playResult = await sendCommand('in_play', { input: uri });
  if (!playResult.ok) return playResult;

  // Wait for VLC to load and start playing, then immediately pause
  await new Promise((resolve) => setTimeout(resolve, 400));

  const pauseResult = await sendCommand('pl_pause');
  return pauseResult.ok ? { ok: true } : pauseResult;
}

// Native fetch with AbortController timeout
async function fetchWithTimeout(url, options, timeoutMs) {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);
  try {
    return await fetch(url, { ...options, signal: controller.signal });
  } finally {
    clearTimeout(timer);
  }
}

module.exports = {
  launchVlc,
  sendCommand,
  getStatus,
  buildFileUri,
  loadAndCue,
  setRepeat,
};
