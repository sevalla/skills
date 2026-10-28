#!/usr/bin/env bash
set -euo pipefail

mkdir -p src public

cat > package.json <<'JSON'
{
  "name": "storefront-web",
  "private": true,
  "type": "module",
  "scripts": {
    "dev": "vite",
    "build": "vite build"
  },
  "dependencies": {
    "react": "^19.2.0",
    "react-dom": "^19.2.0",
    "react-router": "^7.9.0"
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
  <head><meta charset="UTF-8" /><title>Storefront</title></head>
  <body><div id="root"></div><script type="module" src="/src/main.jsx"></script></body>
</html>
HTML

cat > src/main.jsx <<'JSX'
import { createRoot } from "react-dom/client"
import { BrowserRouter, Route, Routes } from "react-router"

const Home = () => <h1>Home</h1>
const Pricing = () => <h1>Pricing</h1>

createRoot(document.getElementById("root")).render(
  <BrowserRouter>
    <Routes>
      <Route path="/" element={<Home />} />
      <Route path="/pricing" element={<Pricing />} />
    </Routes>
  </BrowserRouter>,
)
JSX

printf 'User-agent: *\nAllow: /\n' > public/robots.txt
