'use strict';

const fs = require('fs');
const path = require('path');
const { pipeline } = require('stream/promises');
const { Readable } = require('stream');
const { config } = require('../services/config');

// Reject filenames with path traversal characters
function isSafeFilename(name) {
  return name && !name.includes('..') && !name.includes('/') && !name.includes('\\');
}

// ── Worker routes — registered on all machines ─────────────────────────────

const workerRoutes = [
  // List video files in this machine's videoDirectory
  {
    method: 'GET',
    path: '/files/list',
    handler: async (request, h) => {
      const dir = config.vlc.videoDirectory;
      try {
        const entries = await fs.promises.readdir(dir);
        const files = [];
        for (const name of entries) {
          const stat = await fs.promises.stat(path.join(dir, name));
          if (stat.isFile()) files.push({ name, size: stat.size, mtime: stat.mtimeMs });
        }
        return { ok: true, files };
      } catch (err) {
        return { ok: false, error: err.message, files: [] };
      }
    },
  },

  // Receive a raw binary upload and write to videoDirectory
  {
    method: 'POST',
    path: '/files/upload',
    options: {
      payload: {
        output: 'stream',
        parse: false,
        maxBytes: 10 * 1024 * 1024 * 1024, // 10 GB
        timeout: false,
      },
      timeout: { server: false, socket: false },
    },
    handler: async (request, h) => {
      const filename = request.headers['x-filename'];
      if (!isSafeFilename(filename)) {
        return h.response({ ok: false, error: 'Invalid or missing x-filename header' }).code(400);
      }
      const dest = path.join(config.vlc.videoDirectory, filename);
      try {
        const writeStream = fs.createWriteStream(dest);
        await pipeline(request.payload, writeStream);
        return { ok: true, filename };
      } catch (err) {
        return h.response({ ok: false, error: err.message }).code(500);
      }
    },
  },
];

// ── Master-only routes ─────────────────────────────────────────────────────

const masterRoutes = [
  // Sync all files from master videoDirectory → each worker
  {
    method: 'POST',
    path: '/files/sync',
    options: {
      timeout: { server: false, socket: false },
    },
    handler: async (request, h) => {
      const dir = config.vlc.videoDirectory;

      // Enumerate files on the master
      let files;
      try {
        const entries = await fs.promises.readdir(dir);
        files = [];
        for (const name of entries) {
          const stat = await fs.promises.stat(path.join(dir, name));
          if (stat.isFile()) files.push(name);
        }
      } catch (err) {
        return { ok: false, error: `Cannot read videoDirectory: ${err.message}`, results: {} };
      }

      if (files.length === 0) {
        return { ok: true, fileCount: 0, results: {} };
      }

      const results = {};

      // Push to each worker one file at a time to avoid saturating the link
      for (const [workerId, worker] of Object.entries(config.workers)) {
        const workerResult = { ok: true, transferred: [], errors: [] };
        const baseUrl = `http://${worker.host}:${worker.port}`;

        for (const filename of files) {
          const filepath = path.join(dir, filename);
          try {
            const [fileStream, stat] = await Promise.all([
              Promise.resolve(fs.createReadStream(filepath)),
              fs.promises.stat(filepath),
            ]);

            // Convert Node.js ReadStream → Web ReadableStream for native fetch
            const webStream = Readable.toWeb(fileStream);

            const res = await fetch(`${baseUrl}/files/upload`, {
              method: 'POST',
              headers: {
                'Content-Type': 'application/octet-stream',
                'Content-Length': String(stat.size),
                'x-filename': filename,
              },
              body: webStream,
              duplex: 'half', // required for streaming request bodies in Node 18+
            });

            if (!res.ok) {
              const text = await res.text();
              throw new Error(`HTTP ${res.status}: ${text}`);
            }
            workerResult.transferred.push(filename);
          } catch (err) {
            workerResult.ok = false;
            workerResult.errors.push({ file: filename, error: err.message });
          }
        }

        results[workerId] = workerResult;
      }

      const allOk = Object.values(results).every((r) => r.ok);
      return { ok: allOk, fileCount: files.length, results };
    },
  },
];

module.exports = { workerRoutes, masterRoutes };
