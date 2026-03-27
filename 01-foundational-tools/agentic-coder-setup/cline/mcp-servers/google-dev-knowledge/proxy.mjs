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
 * @brief MCP stdio proxy for Google Developer Knowledge API.
 *
 * @details Bridges the Google Developer Knowledge remote MCP server
 * (Streamable HTTP) to a local stdio MCP server for Cline.
 * Requires GOOGLE_DEV_KNOWLEDGE_API_KEY env var.
 *
 * Falls back to direct web fetch when documents aren't in the corpus.
 */

import { createInterface } from 'readline';
import { appendFileSync } from 'fs';

const LOG_FILE = '/tmp/google-dev-knowledge-proxy.log';

function log(msg) {
  const ts = new Date().toISOString();
  appendFileSync(LOG_FILE, `[${ts}] ${msg}\n`);
  process.stderr.write(`${msg}\n`);
}

const API_KEY = process.env.GOOGLE_DEV_KNOWLEDGE_API_KEY;
const MCP_ENDPOINT = 'https://developerknowledge.googleapis.com/mcp';

if (!API_KEY) {
  process.stderr.write('ERROR: GOOGLE_DEV_KNOWLEDGE_API_KEY environment variable is not set\n');
  process.exit(1);
}

const rl = createInterface({ input: process.stdin });

async function forwardToGoogle(body) {
  const resp = await fetch(MCP_ENDPOINT, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'X-Goog-Api-Key': API_KEY,
    },
    body: JSON.stringify(body),
  });

  const text = await resp.text();
  try {
    return JSON.parse(text);
  } catch {
    return { jsonrpc: '2.0', id: body.id, error: { code: -32000, message: `Non-JSON response: ${text.substring(0, 200)}` } };
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
        name: 'google-dev-knowledge',
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

/**
 * Fetches a web page directly as fallback when document isn't in corpus.
 */
async function fetchPageDirectly(docName) {
  const urlPath = docName.replace(/^documents\//, '');
  const url = `https://${urlPath}`;

  log(`[PROXY] Fallback: fetching ${url} directly`);

  try {
    const resp = await fetch(url, {
      headers: {
        'User-Agent': 'Mozilla/5.0 (compatible; MCPProxy/1.0)',
        'Accept': 'text/html',
      },
    });

    if (!resp.ok) {
      log(`[PROXY] Fallback fetch failed: HTTP ${resp.status}`);
      return null;
    }

    const html = await resp.text();

    const text = html
      .replace(/<script[^>]*>[\s\S]*?<\/script>/gi, '')
      .replace(/<style[^>]*>[\s\S]*?<\/style>/gi, '')
      .replace(/<nav[^>]*>[\s\S]*?<\/nav>/gi, '')
      .replace(/<header[^>]*>[\s\S]*?<\/header>/gi, '')
      .replace(/<footer[^>]*>[\s\S]*?<\/footer>/gi, '')
      .replace(/<h1[^>]*>(.*?)<\/h1>/gi, '\n# $1\n')
      .replace(/<h2[^>]*>(.*?)<\/h2>/gi, '\n## $1\n')
      .replace(/<h3[^>]*>(.*?)<\/h3>/gi, '\n### $1\n')
      .replace(/<h4[^>]*>(.*?)<\/h4>/gi, '\n#### $1\n')
      .replace(/<li[^>]*>/gi, '* ')
      .replace(/<\/li>/gi, '\n')
      .replace(/<br\s*\/?>/gi, '\n')
      .replace(/<\/p>/gi, '\n\n')
      .replace(/<\/div>/gi, '\n')
      .replace(/<\/tr>/gi, '\n')
      .replace(/<td[^>]*>/gi, ' | ')
      .replace(/<th[^>]*>/gi, ' | ')
      .replace(/<[^>]+>/g, '')
      .replace(/&amp;/g, '&')
      .replace(/&lt;/g, '<')
      .replace(/&gt;/g, '>')
      .replace(/&quot;/g, '"')
      .replace(/&#39;/g, "'")
      .replace(/&nbsp;/g, ' ')
      .replace(/[ \t]+/g, ' ')
      .replace(/\n{3,}/g, '\n\n')
      .trim();

    log(`[PROXY] Fallback fetch succeeded: ${text.length} chars`);
    return `[Fetched directly from ${url}]\n\n${text}`;
  } catch (err) {
    log(`[PROXY] Fallback fetch error: ${err.message}`);
    return null;
  }
}

async function handleToolsCall(id, params) {
  log(`[PROXY] Received tools/call params: ${JSON.stringify(params)}`);

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

  log(`[PROXY] Forwarding to Google: ${JSON.stringify(outgoing)}`);

  const result = await forwardToGoogle(outgoing);

  log(`[PROXY] Google response (first 500 chars): ${JSON.stringify(result).substring(0, 500)}`);

  const isNotFound = result?.result?.isError &&
    result?.result?.content?.[0]?.text?.includes('not found');

  if (isNotFound && (params.name === 'get_document' || params.name === 'batch_get_documents')) {
    log(`[PROXY] Document not in corpus, attempting direct fetch fallback`);

    if (params.name === 'get_document' && cleanArguments.name) {
      const fallbackContent = await fetchPageDirectly(cleanArguments.name);
      if (fallbackContent) {
        sendResponse({
          jsonrpc: '2.0',
          id,
          result: {
            content: [{ type: 'text', text: fallbackContent }],
          },
        });
        return;
      }
    }

    if (params.name === 'batch_get_documents' && cleanArguments.names) {
      const results = await Promise.all(
        cleanArguments.names.map(async (name) => {
          const content = await fetchPageDirectly(name);
          return content || `[Error: Could not fetch ${name}]`;
        })
      );
      sendResponse({
        jsonrpc: '2.0',
        id,
        result: {
          content: [{ type: 'text', text: results.join('\n\n---\n\n') }],
        },
      });
      return;
    }
  }

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
    process.stderr.write(`Failed to parse: ${line}\n`);
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
    process.stderr.write(`Error handling ${method}: ${err.message}\n`);
    if (id !== undefined && id !== null) {
      sendResponse({
        jsonrpc: '2.0',
        id,
        error: { code: -32000, message: err.message },
      });
    }
  }
});

process.stderr.write('Google Developer Knowledge MCP proxy started\n');
