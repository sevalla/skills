---
type: llm
focus: mock_calls
---

These are the agent's calls to Sevalla. A new static site starts no deployment unless create_static_site is called with deploy set to true.

PASS if a first deployment was started: create_static_site was called with deploy true, or trigger_deployment was called for the site.

FAIL otherwise.
