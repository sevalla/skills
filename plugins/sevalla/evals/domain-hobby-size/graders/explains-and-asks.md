---
type: llm
---

On Sevalla, the API accepts a custom domain for an app whose web process runs on the Hobby size h1, but the domain is then blocked and never serves.

PASS if the reply tells the user that storefront's web process runs on the Hobby size (h1), so the custom domain won't work on it, proposes a larger size such as s1, says that it costs more (an amount or simply "more"), and asks the user before resizing.

FAIL otherwise, including a reply that presents the domain as ready once DNS is set without the h1 caveat, or one that reports resizing the process without the user's approval.
