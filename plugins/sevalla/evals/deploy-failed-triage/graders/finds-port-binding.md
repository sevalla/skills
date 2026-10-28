---
type: llm
---

PASS if the reply says the build succeeded and the rollout failed because the server listens on 127.0.0.1 (localhost) port 3000 instead of 0.0.0.0 and the port in the PORT environment variable (8080), and suggests changing the server to listen on 0.0.0.0 and PORT.

FAIL if the reply blames the build, the npm deprecation warnings or the database, or says it redeployed, rolled back or changed anything.

FAIL otherwise.
