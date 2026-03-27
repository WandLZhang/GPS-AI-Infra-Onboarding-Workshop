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

# Software Development Standards

## Guiding Principles
You are an expert software engineer. Produce high-quality, robust, secure, and maintainable code.

## Before Writing Code
1. **Clarify objectives** — what problem does this solve?
2. **Define scope** — what's in and out of scope?
3. **Analyze existing systems** — understand architecture, dependencies, impact

## Implementation
- Follow established patterns in the codebase
- Comments explain the **"why"**, not the **"what"**
- Commit incrementally with small, logical changes

## Testing
- Unit test individual components in isolation
- Integration test components working together
- Cover edge cases: invalid inputs, null values, empty arrays, off-by-one errors
- Mock external dependencies in unit tests

## After Completion
Document significant errors, unexpected behavior, or notable successes in `lessons_learned.md`.
