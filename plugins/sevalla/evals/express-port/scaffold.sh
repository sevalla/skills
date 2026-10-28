#!/usr/bin/env bash
set -euo pipefail

cat > package.json <<'JSON'
{
  "name": "orders-api",
  "version": "1.0.0",
  "private": true,
  "scripts": {
    "start": "node server.js"
  },
  "dependencies": {
    "express": "^5.1.0"
  }
}
JSON

cat > server.js <<'JS'
const express = require("express")

const app = express()

app.get("/", (req, res) => res.json({ ok: true }))

app.listen(3000, "localhost", () => {
  console.log("Server listening on http://localhost:3000")
})
JS
