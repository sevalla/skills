#!/usr/bin/env bash
set -euo pipefail

mkdir -p src

cat > package.json <<'JSON'
{
  "name": "landing",
  "private": true,
  "type": "module",
  "scripts": {
    "dev": "vite",
    "build": "vite build"
  },
  "dependencies": {
    "react": "^19.2.0",
    "react-dom": "^19.2.0"
  },
  "devDependencies": {
    "@vitejs/plugin-react": "^5.0.0",
    "vite": "^7.1.0"
  }
}
JSON

cat > vite.config.js <<'JS'
import { defineConfig } from "vite"
import react from "@vitejs/plugin-react"

export default defineConfig({ plugins: [react()] })
JS

cat > index.html <<'HTML'
<!doctype html>
<html lang="en">
  <head><meta charset="UTF-8" /><title>Landing</title></head>
  <body><div id="root"></div><script type="module" src="/src/main.jsx"></script></body>
</html>
HTML

cat > src/main.jsx <<'JSX'
import { createRoot } from "react-dom/client"

createRoot(document.getElementById("root")).render(<h1>Ship faster with Acme</h1>)
JSX

git init -q -b main
git config user.email eval@example.com
git config user.name eval
git add -A
git commit -q -m "Landing page"
git remote add origin https://github.com/acme/landing.git
