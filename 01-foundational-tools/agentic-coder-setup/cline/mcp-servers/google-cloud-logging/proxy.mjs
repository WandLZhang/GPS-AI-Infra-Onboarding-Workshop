#!/usr/bin/env node
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

/**
 * @file proxy.mjs
 * @brief MCP stdio proxy for Google Cloud Logging API.
 *
 * @details Bridges the Google Cloud Logging remote MCP server
 * (Streamable HTTP) to a local stdio MCP server for Cline.
 * Uses OAuth Bearer tokens from gcloud CLI for authentication.
 * Strips Cline-injected fields (task_progress) from tool arguments.
 */

import { createInterface } from 'readline';
import { appendFileSync } from 'fs';
import { execSync } from 'child_process';

const LOG_FILE = '/tmp/google-cloud-logging-proxy.log';
const MCP_ENDPOINT = 'https://logging.googleapis.com/mcp';

function log(msg) {
  const ts = new Date().toISOString();
  appendFileSync(LOG_FILE, `[${ts}] ${msg}\n`);
  process.stderr.write(`${msg}\n`);
}

/**
 * Gets a fresh OAuth access token from gcloud CLI.
 * Caches for 5 minutes. Tokens are valid for ~60 minutes.
 */
let cachedToken = null;
let tokenExpiry = 0;

function getAccessToken() {
  const now = Date.now();
  if (cachedToken && now < tokenExpiry) {
    return cachedToken;
  }

  try {
    cachedToken = execSync('gcloud auth print-access-token 2>/dev/null', {
      encoding: 'utf-8',
    }).trim();
    tokenExpiry = now + 5 * 60 * 1000;
    log('[PROXY] Refreshed access token');
    return cachedToken;
  } catch (err) {
    log(`[PROXY] Failed to get access token: ${err.message}`);
    throw new Error('Failed to get gcloud access token. Run "gcloud auth login" first.');
  }
}

const rl = createInterface({ input: process.stdin });

async function forwardToGoogle(body) {
  const token = getAccessToken();

  const resp = await fetch(MCP_ENDPOINT, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${token}`,
    },
    body: JSON.stringify(body),
  });

  const text = await resp.text();
  try {
    return JSON.parse(text);
  } catch {
    return {
      jsonrpc: '2.0',
      id: body.id,
      error: { code: -32000, message: `Non-JSON response (HTTP ${resp.status}): ${text.substring(0, 300)}` },
    };
  }
}

function sendResponse(response) {
  const json = JSON.stringify(response);
  process.stdout.write(`${json}\n`);
}

function handleInitialize(id) {
  sendResponse({
    jsonrpc: '2.0',
    id,
    result: {
      protocolVersion: '2024-11-05',
      capabilities: {
        tools: { listChanged: false },
      },
      serverInfo: {
        name: 'google-cloud-logging',
        version: '1.0.0',
      },
    },
  });
}

async function handleToolsList(id) {
  const result = await forwardToGoogle({
    jsonrpc: '2.0',
    id: 1,
    method: 'tools/list',
    params: {},
  });

  sendResponse({
    jsonrpc: '2.0',
    id,
    result: result.result || result.error,
  });
}

async function handleToolsCall(id, params) {
  log(`[PROXY] Received tools/call params: ${JSON.stringify(params)}`);

  // Strip injected fields from arguments
  const cleanArguments = { ...params.arguments };
  delete cleanArguments.task_progress;

  const cleanParams = {
    name: params.name,
    arguments: cleanArguments,
  };

  const outgoing = {
    jsonrpc: '2.0',
    id: 1,
    method: 'tools/call',
    params: cleanParams,
  };

  log(`[PROXY] Forwarding to Google: ${JSON.stringify(outgoing).substring(0, 500)}`);

  const result = await forwardToGoogle(outgoing);

  log(`[PROXY] Google response (first 500 chars): ${JSON.stringify(result).substring(0, 500)}`);

  sendResponse({
    jsonrpc: '2.0',
    id,
    result: result.result || { content: [{ type: 'text', text: JSON.stringify(result.error) }] },
  });
}

rl.on('line', async (line) => {
  if (!line.trim()) return;

  let msg;
  try {
    msg = JSON.parse(line);
  } catch {
    log(`Failed to parse: ${line}`);
    return;
  }

  const { id, method, params } = msg;

  try {
    switch (method) {
      case 'initialize':
        handleInitialize(id);
        break;

      case 'initialized':
        break;

      case 'tools/list':
        await handleToolsList(id);
        break;

      case 'tools/call':
        await handleToolsCall(id, params);
        break;

      case 'resources/list':
      case 'prompts/list':
        sendResponse({
          jsonrpc: '2.0',
          id,
          result: method === 'resources/list' ? { resources: [] } : { prompts: [] },
        });
        break;

      case 'notifications/cancelled':
        break;

      default:
        if (id !== undefined && id !== null) {
          sendResponse({
            jsonrpc: '2.0',
            id,
            error: { code: -32601, message: `Method not found: ${method}` },
          });
        }
        break;
    }
  } catch (err) {
    log(`Error handling ${method}: ${err.message}`);
    if (id !== undefined && id !== null) {
      sendResponse({
        jsonrpc: '2.0',
        id,
        error: { code: -32000, message: err.message },
      });
    }
  }
});

log('Google Cloud Logging MCP proxy started');
