#!/usr/bin/env node
// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Chris <goabonga@pm.me>
//
// Build the shomer-ssr frontend assets and sync them into the
// downstream Python package. Outputs land directly under
// packages/ssr/src/shomer_ssr/{static,templates}/ — that's the only
// place Python at runtime will read them from.
//
//   src/main.ts           ──> esbuild bundle ──> static/main.js
//   src/styles.css        ──> esbuild bundle ──> static/main.css
//   src/templates/*.html  ──> verbatim copy   ──> templates/
//
// Templates get an "AUTO-GENERATED" comment prepended so a Python
// dev who edits packages/ssr/src/shomer_ssr/templates/login.html
// directly knows to fix it upstream in web instead.

import * as esbuild from "esbuild";
import { mkdirSync, readdirSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = dirname(fileURLToPath(import.meta.url));
const ROOT = resolve(__dirname, "..");
const SRC = join(ROOT, "src");
const OUT_STATIC = resolve(ROOT, "..", "ssr", "src", "shomer_ssr", "static");
const OUT_TEMPLATES = resolve(ROOT, "..", "ssr", "src", "shomer_ssr", "templates");

const AUTO_GEN_COMMENT_HTML = (sourcePath) =>
  `<!-- AUTO-GENERATED from packages/web/src/templates/${sourcePath} - DO NOT EDIT -->\n`;

function ensureDir(dir) {
  mkdirSync(dir, { recursive: true });
}

function buildJs() {
  return esbuild.build({
    entryPoints: [join(SRC, "main.ts")],
    bundle: true,
    minify: true,
    format: "iife",
    target: "es2022",
    outfile: join(OUT_STATIC, "main.js"),
    logLevel: "info",
  });
}

function buildCss() {
  return esbuild.build({
    entryPoints: [join(SRC, "styles.css")],
    bundle: true,
    minify: true,
    outfile: join(OUT_STATIC, "main.css"),
    logLevel: "info",
  });
}

function buildTemplates() {
  // Wipe the destination so deleted source templates disappear too.
  rmSync(OUT_TEMPLATES, { recursive: true, force: true });
  ensureDir(OUT_TEMPLATES);

  const srcDir = join(SRC, "templates");
  const entries = readdirSync(srcDir, { withFileTypes: true });
  for (const entry of entries) {
    if (!entry.isFile() || !entry.name.endsWith(".html")) continue;
    const body = readFileSync(join(srcDir, entry.name), "utf8");
    writeFileSync(
      join(OUT_TEMPLATES, entry.name),
      AUTO_GEN_COMMENT_HTML(entry.name) + body,
    );
    console.log(`templates/${entry.name} -> ${OUT_TEMPLATES}/${entry.name}`);
  }
}

ensureDir(OUT_STATIC);
await Promise.all([buildJs(), buildCss()]);
buildTemplates();
console.log("done.");
