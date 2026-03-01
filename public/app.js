'use strict';

// ── State ──────────────────────────────────────────────────────────────────
let cues = [];
let lastFiredCueId = null;

// ── Init ───────────────────────────────────────────────────────────────────
async function init() {
  try {
    const data = await apiFetch('/api/config');
    cues = data.cues || [];
    renderCueList();
  } catch (e) {
    showError('err-admin', 'Failed to load config: ' + e.message);
  }

  startStatusPoller();
  startClock();
}

// ── Cue List ───────────────────────────────────────────────────────────────
function renderCueList() {
  const tbody = document.getElementById('cue-tbody');
  if (!cues.length) {
    tbody.innerHTML = '<tr><td colspan="6" style="padding:16px;color:var(--text-muted);">No cues defined in cues.json</td></tr>';
    return;
  }

  tbody.innerHTML = cues.map((cue) => {
    const actionText = cue.action === 'load' && cue.file
      ? `load — ${escHtml(cue.file)}`
      : cue.action;

    return `
      <tr id="cue-row-${cue.id}">
        <td class="cue-num">${cue.id}</td>
        <td class="cue-main">
          <div class="cue-label">${escHtml(cue.label)}</div>
          <div class="cue-meta"><span class="cue-target">${cue.target}</span><span class="cue-action">${actionText}</span></div>
          ${cue.notes ? `<div class="cue-notes">${escHtml(cue.notes)}</div>` : ''}
        </td>
        <td class="cue-result" id="cue-result-${cue.id}"></td>
        <td class="cue-go"><button class="btn-go" onclick="triggerCue(${cue.id})">GO</button></td>
      </tr>`;
  }).join('');
}

async function triggerCue(cueId) {
  const cue = cues.find((c) => c.id === cueId);
  if (!cue) return;

  // Highlight the active row
  if (lastFiredCueId) {
    document.getElementById(`cue-row-${lastFiredCueId}`)?.classList.remove('cue-active');
  }
  document.getElementById(`cue-row-${cueId}`)?.classList.add('cue-active');
  lastFiredCueId = cueId;

  // Clear previous result
  const resultCell = document.getElementById(`cue-result-${cueId}`);
  if (resultCell) resultCell.textContent = '⏳';

  // Build body
  const body = {};
  if (cue.file) body.file = cue.file;
  if (cue.seekTime !== undefined) body.time = cue.seekTime;
  if (cue.loop !== undefined) body.loop = cue.loop;

  try {
    const result = await apiFetch(`/groups/${cue.target}/vlc/${cue.action}`, 'POST', body);
    if (resultCell) resultCell.textContent = result.ok ? '✅' : '❌';
    if (!result.ok) {
      const errors = Object.entries(result.results || {})
        .filter(([, r]) => !r.ok)
        .map(([id, r]) => `${id}: ${r.error}`)
        .join('; ');
      showError('err-admin', errors || JSON.stringify(result));
    }
  } catch (e) {
    if (resultCell) resultCell.textContent = '❌';
    showError('err-admin', e.message);
  }
}

// ── Manual Group Controls ──────────────────────────────────────────────────
async function groupCmd(group, command) {
  const errId = group === 'C' ? 'err-c' : 'err-ab';
  clearError(errId);

  const body = {};
  if (command === 'load' || command === 'play') {
    const loopCheckbox = document.getElementById(group === 'C' ? 'loop-c' : 'loop-ab');
    if (loopCheckbox) body.loop = loopCheckbox.checked;
  }
  if (command === 'load') {
    const fileInput = document.getElementById(group === 'C' ? 'file-c' : 'file-ab');
    const file = fileInput?.value.trim();
    if (!file) { showError(errId, 'Enter a filename first'); return; }
    body.file = file;
  }

  try {
    const result = await apiFetch(`/groups/${group}/vlc/${command}`, 'POST', body);
    if (!result.ok) {
      const errors = Object.entries(result.results || {})
        .filter(([, r]) => !r.ok)
        .map(([id, r]) => `${id}: ${r.error}`)
        .join('; ');
      showError(errId, errors || 'Command failed');
    }
  } catch (e) {
    showError(errId, e.message);
  }
}

async function groupSeek(group) {
  const errId = group === 'C' ? 'err-c' : 'err-ab';
  clearError(errId);
  const seekInput = document.getElementById(group === 'C' ? 'seek-c' : 'seek-ab');
  const time = parseInt(seekInput?.value, 10);
  if (isNaN(time)) { showError(errId, 'Enter a valid time in seconds'); return; }

  try {
    const result = await apiFetch(`/groups/${group}/vlc/seek`, 'POST', { time });
    if (!result.ok) showError(errId, 'Seek failed');
  } catch (e) {
    showError(errId, e.message);
  }
}

async function reloadCues() {
  try {
    const data = await apiFetch('/api/config');
    cues = data.cues || [];
    lastFiredCueId = null;
    renderCueList();
    console.log('Cues reloaded:', cues.length, 'cues');
  } catch (e) {
    showError('err-admin', 'Failed to reload cues: ' + e.message);
  }
}

async function launchVlc(machineId) {
  clearError('err-admin');
  try {
    const result = await apiFetch(`/machines/${machineId}/vlc/launch`, 'POST', {});
    if (!result.ok) showError('err-admin', `Launch failed on ${machineId}: ${result.error}`);
  } catch (e) {
    showError('err-admin', e.message);
  }
}

// ── Status Polling ─────────────────────────────────────────────────────────
function startStatusPoller() {
  pollStatus(); // immediate first poll
  setInterval(pollStatus, 2000);
}

async function pollStatus() {
  const machines = ['A', 'B', 'C'];
  const results = await Promise.allSettled(
    machines.map((id) => apiFetch(`/machines/${id}/vlc/status`))
  );

  results.forEach((r, i) => {
    const id = machines[i];
    if (r.status === 'fulfilled') {
      // REST responded — VLC may or may not be running
      updateMachineStatus(id, true, r.value);
    } else {
      // Network failure — REST service itself is unreachable
      updateMachineStatus(id, false, null);
    }
  });
}

function updateMachineStatus(id, restOk, data) {
  const badge  = document.getElementById(`badge-${id}`);
  const dot    = document.getElementById(`rest-${id}`);
  const fileEl = document.getElementById(`file-${id}`);
  if (!badge) return;

  // REST dot
  if (dot) {
    dot.className = restOk ? 'rest-dot rest-ok' : 'rest-dot rest-offline';
    dot.title = restOk ? 'REST: responding' : 'REST: offline';
  }

  if (!restOk) {
    // Can't reach the Node server at all
    badge.textContent = 'VLC offline';
    badge.className = 'badge badge-unknown';
    if (fileEl) fileEl.textContent = '';
    return;
  }

  if (!data.ok) {
    // REST is up but VLC isn't responding
    badge.textContent = 'VLC offline';
    badge.className = 'badge badge-unknown';
    if (fileEl) fileEl.textContent = '';
    return;
  }

  // VLC is running — show its state
  const state = data.state || 'stopped';
  if (state === 'playing') {
    badge.textContent = 'playing';
    badge.className = 'badge badge-playing';
  } else if (state === 'paused') {
    badge.textContent = 'paused';
    badge.className = 'badge badge-paused';
  } else {
    // stopped — VLC is open and ready
    badge.textContent = 'VLC Running';
    badge.className = 'badge badge-vlcrunning';
  }
  if (fileEl) fileEl.textContent = data.filename || '';
}

// ── Clock ──────────────────────────────────────────────────────────────────
function startClock() {
  const el = document.getElementById('header-time');
  if (!el) return;
  setInterval(() => {
    el.textContent = new Date().toLocaleTimeString();
  }, 1000);
}

// ── Helpers ────────────────────────────────────────────────────────────────
async function apiFetch(url, method = 'GET', body = null) {
  const opts = {
    method,
    headers: { 'Content-Type': 'application/json' },
  };
  if (body && method !== 'GET') opts.body = JSON.stringify(body);
  const res = await fetch(url, opts);
  if (!res.ok) {
    const text = await res.text();
    throw new Error(`HTTP ${res.status}: ${text}`);
  }
  return res.json();
}

function showError(id, msg) {
  const el = document.getElementById(id);
  if (!el) return;
  el.textContent = msg;
  el.classList.add('visible');
  setTimeout(() => el.classList.remove('visible'), 6000);
}

function clearError(id) {
  const el = document.getElementById(id);
  if (el) el.classList.remove('visible');
}

function escHtml(str) {
  return str.replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;');
}

// ── Bootstrap ─────────────────────────────────────────────────────────────
window.addEventListener('DOMContentLoaded', init);
