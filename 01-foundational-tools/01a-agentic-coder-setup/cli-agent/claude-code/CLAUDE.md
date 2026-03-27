<!--
Copyright 2026 Google LLC

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    https://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
-->

# Global Rules for Claude Code

## Python
- NEVER run python or pip directly. Always use: `source .venv/bin/activate && python ...` OR `source venv/bin/activate && python ...`

## File Management
- NEVER create markdown or text files telling me what to do — just walk through and run the deployments
- NEVER create new scripts when you can replace/update the old script that is not working. No "enhanced_" or "v2_" files

## Data Integrity
- NEVER use mock or fake data. Test real systems. Do not simulate responses — solve the real problem and if you cannot, say so.
- When code sends payloads between functions, ALWAYS include log statements capturing the full payload for troubleshooting.

## Output
- NEVER truncate output or limit reading. Do NOT use head, tail, or pipes that reduce output. Always capture and display full command output.
