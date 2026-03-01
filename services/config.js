'use strict';

const path = require('path');

const configFile = process.argv[2] || 'config.json';
const config = require(path.resolve(__dirname, '..', configFile));
const cues   = require(path.resolve(__dirname, '..', 'cues.json'));

module.exports = { config, cues };
