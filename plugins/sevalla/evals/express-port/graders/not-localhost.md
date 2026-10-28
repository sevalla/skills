---
type: regex
pattern: listen\([^)]*(localhost|127\.0\.0\.1)
match: not_contains
target:
  source: file
  path: server.js
---
