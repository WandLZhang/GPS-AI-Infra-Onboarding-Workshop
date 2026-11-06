// Copyright 2026 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     https://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

// Claude Code's VS Code extension archives a session after 14 idle days unless
// claudeCode.archiveInactiveSessions is 0 (Never). The key is application-scoped,
// so VS Code reads it only from User settings, and Code OSS keeps User settings
// in the browser: one copy per browser profile and per workstation URL. No file
// on the workstation can set it. This extension runs on the workstation and
// writes the key into the User settings of each browser that opens it.
const fs = require('fs');
const os = require('os');
const path = require('path');
const vscode = require('vscode');

const SECTION = 'claudeCode';
const KEY = 'archiveInactiveSessions';
const LOG = path.join(os.homedir(), '.cache', 'keep-claude-sessions.log');

function log(message) {
  const line = `${new Date().toISOString()} ${message}\n`;
  try {
    fs.mkdirSync(path.dirname(LOG), { recursive: true });
    fs.appendFileSync(LOG, line);
  } catch (err) {
    console.error(`keep-claude-sessions: can't write ${LOG}: ${err}`);
  }
}

async function activate() {
  const before = vscode.workspace.getConfiguration(SECTION).inspect(KEY);
  log(`before: ${JSON.stringify(before)}`);
  if (before?.globalValue === 0) return;
  try {
    log(`update: ${SECTION}.${KEY} = 0 in User settings`);
    await vscode.workspace.getConfiguration(SECTION).update(KEY, 0, vscode.ConfigurationTarget.Global);
    log(`after: ${JSON.stringify(vscode.workspace.getConfiguration(SECTION).inspect(KEY))}`);
  } catch (err) {
    log(`update failed: ${err}`);
  }
}

module.exports = { activate, deactivate() {} };
