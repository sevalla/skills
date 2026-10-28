---
type: llm
---

On Sevalla, custom domains don't work with an application whose web process runs on the Hobby size h1.

PASS if the reply tells the user that storefront's web process runs on the Hobby size (h1), which doesn't support custom domains, proposes a larger size such as s1, says that it costs more (an amount or simply "more"), and asks the user before resizing.

FAIL otherwise, including a reply that presents the domain as working on h1 once DNS is set, or one that reports resizing the process without the user's approval.
