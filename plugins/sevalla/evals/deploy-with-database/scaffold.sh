#!/usr/bin/env bash
set -euo pipefail

mkdir -p prisma

cat > package.json <<'JSON'
{
  "name": "orders-api",
  "version": "1.0.0",
  "private": true,
  "engines": { "node": "24.x" },
  "scripts": {
    "build": "prisma generate",
    "migrate": "prisma migrate deploy",
    "start": "node server.js"
  },
  "dependencies": {
    "@prisma/client": "^6.18.0",
    "express": "^5.1.0"
  },
  "devDependencies": {
    "prisma": "^6.18.0"
  }
}
JSON

cat > prisma/schema.prisma <<'PRISMA'
datasource db {
  provider = "postgresql"
  url      = env("DATABASE_URL")
}

generator client {
  provider = "prisma-client-js"
}

model Order {
  id        Int      @id @default(autoincrement())
  total     Int
  createdAt DateTime @default(now())
}
PRISMA

cat > server.js <<'JS'
const express = require("express")
const { PrismaClient } = require("@prisma/client")

const db = new PrismaClient()
const app = express()

app.get("/orders", async (req, res) => res.json(await db.order.findMany()))

app.listen(process.env.PORT || 8080, "0.0.0.0")
JS

mkdir -p prisma/migrations/20261020090000_init
printf 'provider = "postgresql"\n' > prisma/migrations/migration_lock.toml
cat > prisma/migrations/20261020090000_init/migration.sql <<'SQL'
CREATE TABLE "Order" (
    "id" SERIAL NOT NULL,
    "total" INTEGER NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "Order_pkey" PRIMARY KEY ("id")
);
SQL

printf 'DATABASE_URL=postgresql://localhost:5432/orders\n' > .env.example

git init -q -b main
git config user.email eval@example.com
git config user.name eval
git add -A
git commit -q -m "Orders API"
git remote add origin https://github.com/acme/orders-api.git
