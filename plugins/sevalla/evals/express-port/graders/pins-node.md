---
type: regex
weight: 0.5
pattern: '"engines"\s*:\s*\{[^}]*"node"'
target:
  source: file
  path: package.json
---
