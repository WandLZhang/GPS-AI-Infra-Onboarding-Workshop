---
marp: true
html: true
theme: gps-onboarding
paginate: true
title: Fast Science Setup
---

<!--
Copyright 2026 Google LLC
Licensed under the Apache License, Version 2.0
-->

<!-- _class: title -->

# Fast Science Setup

<div style="display:flex;gap:12px;align-items:center;margin:24px 0 40px;font-size:16px;font-weight:400;">
  <span style="background:#fff7d6;padding:6px 16px;border-radius:20px;border:1px solid #f9ab00;color:#3c4043;">gcloud</span>
  <span style="color:#80868b;">→</span>
  <span style="background:#d6e8ff;padding:6px 16px;border-radius:20px;border:1px solid #1a73e8;color:#3c4043;">VS Code + Cline</span>
  <span style="color:#80868b;">→</span>
  <span style="background:#e8f5e9;padding:6px 16px;border-radius:20px;border:1px solid #1e8e3e;color:#3c4043;">deploy landing zone</span>
</div>

---

<!-- Overview: three big boxes -->

<div style="display:flex;flex-direction:column;justify-content:center;height:100%;gap:0;">
  <div style="background:#fff7d6;border:2px solid #f9ab00;border-radius:12px;padding:28px 40px;text-align:center;font-size:30px;font-weight:500;color:#202124;">Install programs</div>
  <div style="text-align:center;font-size:24px;color:#80868b;margin:12px 0;">↓</div>
  <div style="background:#d6e8ff;border:2px solid #1a73e8;border-radius:12px;padding:28px 40px;text-align:center;font-size:30px;font-weight:500;color:#202124;">Set up access</div>
  <div style="text-align:center;font-size:24px;color:#80868b;margin:12px 0;">↓</div>
  <div style="background:#e8f5e9;border:2px solid #1e8e3e;border-radius:12px;padding:28px 40px;text-align:center;font-size:30px;font-weight:500;color:#202124;">Configure Cline / Claude Code</div>
</div>

---

<!-- Install programs (alone) -->

<div style="display:flex;flex-direction:column;justify-content:center;height:100%;gap:0;">
  <div style="background:#fff7d6;border:2px solid #f9ab00;border-radius:12px;padding:28px 40px;text-align:center;font-size:30px;font-weight:500;color:#202124;">Install programs</div>
</div>

---

<!-- Expand: Install gcloud | Install VS Code -->

<div style="display:flex;flex-direction:column;justify-content:center;height:100%;gap:0;">
  <div style="display:flex;gap:16px;margin:0;">
    <div style="flex:1;background:#fff7d6;border:2px solid #f9ab00;border-radius:12px;padding:24px 20px;text-align:center;font-size:24px;font-weight:500;color:#202124;">Install <a href="https://cloud.google.com/sdk/docs/install" style="color:#1a73e8;">gcloud</a></div>
    <div style="flex:1;background:#fff7d6;border:2px solid #f9ab00;border-radius:12px;padding:24px 20px;text-align:center;font-size:24px;font-weight:500;color:#202124;">Install <a href="https://code.visualstudio.com/" style="color:#1a73e8;">VS Code</a></div>
  </div>
</div>

---

<!-- Add: Set up access -->

<div style="display:flex;flex-direction:column;justify-content:center;height:100%;gap:0;">
  <div style="display:flex;gap:16px;margin:0;">
    <div style="flex:1;background:#fff7d6;border:2px solid #f9ab00;border-radius:12px;padding:24px 20px;text-align:center;font-size:24px;font-weight:500;color:#202124;">Install gcloud</div>
    <div style="flex:1;background:#fff7d6;border:2px solid #f9ab00;border-radius:12px;padding:24px 20px;text-align:center;font-size:24px;font-weight:500;color:#202124;">Install VS Code</div>
  </div>
  <div style="text-align:center;font-size:24px;color:#80868b;margin:12px 0;">↓</div>
  <div style="background:#d6e8ff;border:2px solid #1a73e8;border-radius:12px;padding:28px 40px;text-align:center;font-size:30px;font-weight:500;color:#202124;">Set up access</div>
</div>

---

<!-- Config sub-box 1: Enable Opus -->

<div style="display:flex;flex-direction:column;justify-content:center;height:100%;gap:0;">
  <div style="display:flex;gap:16px;margin:0;">
    <div style="flex:1;background:#fff7d6;border:2px solid #f9ab00;border-radius:12px;padding:24px 20px;text-align:center;font-size:24px;font-weight:500;color:#202124;">Install gcloud</div>
    <div style="flex:1;background:#fff7d6;border:2px solid #f9ab00;border-radius:12px;padding:24px 20px;text-align:center;font-size:24px;font-weight:500;color:#202124;">Install VS Code</div>
  </div>
  <div style="text-align:center;font-size:24px;color:#80868b;margin:12px 0;">↓</div>
  <div style="display:flex;justify-content:center;margin:0;">
    <div style="background:#d6e8ff;border:2px solid #1a73e8;border-radius:12px;padding:20px 40px;text-align:center;font-size:20px;font-weight:500;color:#202124;">Enable <a href="https://console.cloud.google.com/vertex-ai/publishers/anthropic/model-garden/claude-opus-4-6" style="color:#1a73e8;">Opus 4.6</a> / <a href="https://console.cloud.google.com/vertex-ai/publishers/anthropic/model-garden/claude-opus-4-7" style="color:#1a73e8;">Opus 4.7</a><br/><span style="font-size:14px;font-weight:400;color:#5f6368;">Vertex Model Garden</span></div>
  </div>
</div>

---

<!-- Config sub-box 2: + gcloud auth -->

<div style="display:flex;flex-direction:column;justify-content:center;height:100%;gap:0;">
  <div style="display:flex;gap:16px;margin:0;">
    <div style="flex:1;background:#fff7d6;border:2px solid #f9ab00;border-radius:12px;padding:24px 20px;text-align:center;font-size:24px;font-weight:500;color:#202124;">Install gcloud</div>
    <div style="flex:1;background:#fff7d6;border:2px solid #f9ab00;border-radius:12px;padding:24px 20px;text-align:center;font-size:24px;font-weight:500;color:#202124;">Install VS Code</div>
  </div>
  <div style="text-align:center;font-size:24px;color:#80868b;margin:12px 0;">↓</div>
  <div style="display:flex;gap:12px;margin:0;">
    <div style="flex:1;background:#d6e8ff;border:2px solid #1a73e8;border-radius:12px;padding:20px 16px;text-align:center;display:flex;align-items:center;justify-content:center;flex-direction:column;font-size:20px;font-weight:500;color:#202124;">Enable Opus 4.6 / 4.7<br/><span style="font-size:14px;font-weight:400;color:#5f6368;">Vertex Model Garden</span></div>
    <div style="flex:1;background:#d6e8ff;border:2px solid #1a73e8;border-radius:12px;padding:20px 16px;text-align:center;display:flex;align-items:center;justify-content:center;flex-direction:column;font-size:20px;font-weight:500;color:#202124;"><code style="font-size:13px;white-space:nowrap;">gcloud auth login</code><br/><code style="font-size:13px;white-space:nowrap;">gcloud auth application-default login</code></div>
  </div>
</div>

---

<!-- Config sub-box 3: + Cline settings + screenshot -->

<div style="display:flex;flex-direction:column;height:100%;gap:0;">
  <div style="display:flex;gap:16px;margin:0;">
    <div style="flex:1;background:#fff7d6;border:2px solid #f9ab00;border-radius:12px;padding:16px 20px;text-align:center;font-size:22px;font-weight:500;color:#202124;">Install gcloud</div>
    <div style="flex:1;background:#fff7d6;border:2px solid #f9ab00;border-radius:12px;padding:16px 20px;text-align:center;font-size:22px;font-weight:500;color:#202124;">Install VS Code</div>
  </div>
  <div style="text-align:center;font-size:20px;color:#80868b;margin:8px 0;">↓</div>
  <div style="display:flex;gap:12px;margin:0;">
    <div style="flex:1;background:#d6e8ff;border:2px solid #1a73e8;border-radius:12px;padding:14px 12px;text-align:center;display:flex;align-items:center;justify-content:center;flex-direction:column;font-size:18px;font-weight:500;color:#202124;">Enable Opus 4.6 / 4.7<br/><span style="font-size:13px;font-weight:400;color:#5f6368;">Vertex Model Garden</span></div>
    <div style="flex:1;background:#d6e8ff;border:2px solid #1a73e8;border-radius:12px;padding:14px 12px;text-align:center;display:flex;align-items:center;justify-content:center;flex-direction:column;font-size:18px;font-weight:500;color:#202124;"><code style="font-size:12px;white-space:nowrap;">gcloud auth login</code><br/><code style="font-size:12px;white-space:nowrap;">gcloud auth application-default login</code></div>
    <div style="flex:1;background:#d6e8ff;border:2px solid #1a73e8;border-radius:12px;padding:14px 12px;text-align:center;display:flex;align-items:center;justify-content:center;flex-direction:column;font-size:18px;font-weight:500;color:#202124;">Cline settings</div>
  </div>
  <div style="display:flex;justify-content:center;margin:16px 0 0 0;">
    <img src="visuals/cline-settings.png" style="border:1px solid #ccc;border-radius:8px;max-height:300px;" />
  </div>
</div>

---

<!-- Config sub-box 4: + Sign up for GitHub -->

<div style="display:flex;flex-direction:column;height:100%;gap:0;">
  <div style="display:flex;gap:16px;margin:0;">
    <div style="flex:1;background:#fff7d6;border:2px solid #f9ab00;border-radius:12px;padding:16px 20px;text-align:center;font-size:22px;font-weight:500;color:#202124;">Install gcloud</div>
    <div style="flex:1;background:#fff7d6;border:2px solid #f9ab00;border-radius:12px;padding:16px 20px;text-align:center;font-size:22px;font-weight:500;color:#202124;">Install VS Code</div>
  </div>
  <div style="text-align:center;font-size:20px;color:#80868b;margin:8px 0;">↓</div>
  <div style="display:flex;gap:12px;margin:0;">
    <div style="flex:1;background:#d6e8ff;border:2px solid #1a73e8;border-radius:12px;padding:14px 12px;text-align:center;display:flex;align-items:center;justify-content:center;flex-direction:column;font-size:18px;font-weight:500;color:#202124;">Enable Opus 4.6 / 4.7</div>
    <div style="flex:1;background:#d6e8ff;border:2px solid #1a73e8;border-radius:12px;padding:14px 12px;text-align:center;display:flex;align-items:center;justify-content:center;flex-direction:column;font-size:18px;font-weight:500;color:#202124;"><code style="font-size:12px;white-space:nowrap;">gcloud auth login</code><br/><code style="font-size:12px;white-space:nowrap;">gcloud auth application-default login</code></div>
    <div style="flex:1;background:#d6e8ff;border:2px solid #1a73e8;border-radius:12px;padding:14px 12px;text-align:center;display:flex;align-items:center;justify-content:center;flex-direction:column;font-size:18px;font-weight:500;color:#202124;">Cline settings</div>
    <div style="flex:1;background:#d6e8ff;border:2px solid #1a73e8;border-radius:12px;padding:14px 12px;text-align:center;display:flex;align-items:center;justify-content:center;flex-direction:column;font-size:18px;font-weight:500;color:#202124;">Sign up for <a href="https://github.com/signup" style="color:#1a73e8;">GitHub</a></div>
  </div>
</div>

---

<!-- Final: Configure Cline / Claude Code + the prompt -->

<!-- _class: compact -->

<div style="display:flex;flex-direction:column;height:100%;gap:0;">
  <div style="display:flex;gap:12px;margin:0;">
    <div style="flex:1;background:#fff7d6;border:1px solid #f9ab00;border-radius:10px;padding:14px 12px;text-align:center;font-size:18px;font-weight:500;color:#202124;">Install gcloud</div>
    <div style="flex:1;background:#fff7d6;border:1px solid #f9ab00;border-radius:10px;padding:14px 12px;text-align:center;font-size:18px;font-weight:500;color:#202124;">Install VS Code</div>
  </div>
  <div style="text-align:center;font-size:18px;color:#80868b;margin:6px 0;">↓</div>
  <div style="display:flex;gap:8px;margin:0;">
    <div style="flex:1;background:#d6e8ff;border:1px solid #1a73e8;border-radius:10px;padding:12px 8px;text-align:center;font-size:14px;font-weight:500;color:#202124;">Enable Opus</div>
    <div style="flex:1;background:#d6e8ff;border:1px solid #1a73e8;border-radius:10px;padding:12px 8px;text-align:center;font-size:14px;font-weight:500;color:#202124;">gcloud auth</div>
    <div style="flex:1;background:#d6e8ff;border:1px solid #1a73e8;border-radius:10px;padding:12px 8px;text-align:center;font-size:14px;font-weight:500;color:#202124;">Cline settings</div>
    <div style="flex:1;background:#d6e8ff;border:1px solid #1a73e8;border-radius:10px;padding:12px 8px;text-align:center;font-size:14px;font-weight:500;color:#202124;">GitHub</div>
  </div>
  <div style="text-align:center;font-size:18px;color:#80868b;margin:6px 0;">↓</div>
  <div style="background:#e8f5e9;border:2px solid #1e8e3e;border-radius:12px;padding:16px 24px;font-size:16px;color:#202124;">
    <div style="font-size:24px;font-weight:500;text-align:center;margin-bottom:12px;">Configure Cline / Claude Code</div>
    <div style="background:#fff;border-radius:8px;padding:14px 18px;border:1px solid #e8eaed;font-size:15px;line-height:1.7;">
      <strong>Paste into Cline:</strong><br/>
      Please install the MCPs and Claude Code according to <a href="https://github.com/WandLZhang/GPS-AI-Infra-Onboarding-Workshop/tree/main/01-foundational-tools/agentic-coder-setup" style="color:#1a73e8;">https://github.com/WandLZhang/GPS-AI-Infra-Onboarding-Workshop/tree/main/01-foundational-tools/agentic-coder-setup</a>. You may have to install <code>gh</code> and ask the user to <code>gh auth</code> in the terminal.
    </div>
  </div>
</div>

---

<!-- Next: use Cline to deploy fast-science -->

<!-- _class: compact -->

<div style="display:flex;flex-direction:column;height:100%;gap:0;">
  <div style="display:flex;gap:12px;margin:0;">
    <div style="flex:1;background:#fff7d6;border:1px solid #f9ab00;border-radius:10px;padding:14px 12px;text-align:center;font-size:18px;font-weight:500;color:#202124;">Install gcloud</div>
    <div style="flex:1;background:#fff7d6;border:1px solid #f9ab00;border-radius:10px;padding:14px 12px;text-align:center;font-size:18px;font-weight:500;color:#202124;">Install VS Code</div>
  </div>
  <div style="text-align:center;font-size:18px;color:#80868b;margin:6px 0;">↓</div>
  <div style="display:flex;gap:8px;margin:0;">
    <div style="flex:1;background:#d6e8ff;border:1px solid #1a73e8;border-radius:10px;padding:12px 8px;text-align:center;font-size:14px;font-weight:500;color:#202124;">Enable Opus</div>
    <div style="flex:1;background:#d6e8ff;border:1px solid #1a73e8;border-radius:10px;padding:12px 8px;text-align:center;font-size:14px;font-weight:500;color:#202124;">gcloud auth</div>
    <div style="flex:1;background:#d6e8ff;border:1px solid #1a73e8;border-radius:10px;padding:12px 8px;text-align:center;font-size:14px;font-weight:500;color:#202124;">Cline settings</div>
    <div style="flex:1;background:#d6e8ff;border:1px solid #1a73e8;border-radius:10px;padding:12px 8px;text-align:center;font-size:14px;font-weight:500;color:#202124;">GitHub</div>
  </div>
  <div style="text-align:center;font-size:18px;color:#80868b;margin:6px 0;">↓</div>
  <div style="background:#e8f5e9;border:1px solid #1e8e3e;border-radius:10px;padding:12px 18px;font-size:14px;font-weight:500;color:#202124;text-align:center;">Configure Cline / Claude Code</div>
  <div style="text-align:center;font-size:18px;color:#80868b;margin:6px 0;">↓</div>
  <div style="background:#e8f5e9;border:2px solid #1e8e3e;border-radius:12px;padding:16px 24px;font-size:16px;color:#202124;">
    <div style="font-size:24px;font-weight:500;text-align:center;margin-bottom:12px;">Use Cline to deploy fast-science</div>
    <div style="background:#fff;border-radius:8px;padding:14px 18px;border:1px solid #e8eaed;font-size:15px;line-height:1.7;">
      <strong>L0 — Landing Zone</strong><br/>
      <a href="https://github.com/WandLZhang/fast-science-0-stellar-engine" style="color:#1a73e8;">https://github.com/WandLZhang/fast-science-0-stellar-engine</a><br/><br/>
      <strong>L1 — Researcher Lab</strong><br/>
      <a href="https://github.com/WandLZhang/fast-science-1-researcher-lab" style="color:#1a73e8;">https://github.com/WandLZhang/fast-science-1-researcher-lab</a>
    </div>
  </div>
</div>

<script>document.querySelectorAll('a[href^="http"]').forEach(a=>a.target='_blank')</script>
