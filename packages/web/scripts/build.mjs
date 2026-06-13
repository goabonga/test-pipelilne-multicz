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
import {
  mkdirSync,
  readdirSync,
  readFileSync,
  rmSync,
  watch,
  writeFileSync,
} from "node:fs";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = dirname(fileURLToPath(import.meta.url));
const ROOT = resolve(__dirname, "..");
const SRC = join(ROOT, "src");

// In dev (compose), OUTPUT_STATIC / OUTPUT_TEMPLATES are set so the
// build writes to a path the ssr container also bind-mounts. In a
// plain workspace checkout (or in CI), the env vars are absent and we
// keep writing into packages/ssr/src/shomer_ssr/, which multicz then
// tracks as part of the ssr release.
const OUT_STATIC =
  process.env.OUTPUT_STATIC || resolve(ROOT, "..", "ssr", "src", "shomer_ssr", "static");
const OUT_TEMPLATES =
  process.env.OUTPUT_TEMPLATES || resolve(ROOT, "..", "ssr", "src", "shomer_ssr", "templates");

const WATCH = process.argv.includes("--watch");

const AUTO_GEN_COMMENT_HTML = (sourcePath) =>
  `<!-- AUTO-GENERATED from packages/web/src/templates/${sourcePath} - DO NOT EDIT -->\n`;

function ensureDir(dir) {
  mkdirSync(dir, { recursive: true });
}

const jsConfig = {
  entryPoints: [join(SRC, "main.ts")],
  bundle: true,
  // Skip minification in watch mode — saves a few ms per rebuild and
  // keeps the bundle readable in browser devtools while iterating.
  minify: !WATCH,
  format: "iife",
  target: "es2022",
  outfile: join(OUT_STATIC, "main.js"),
  logLevel: "info",
};

const cssConfig = {
  entryPoints: [join(SRC, "styles.css")],
  bundle: true,
  minify: !WATCH,
  outfile: join(OUT_STATIC, "main.css"),
  logLevel: "info",
};

function buildJs() {
  return esbuild.build(jsConfig);
}

function buildCss() {
  return esbuild.build(cssConfig);
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

if (WATCH) {
  // esbuild's context API handles JS + CSS rebuilds incrementally —
  // it watches every transitive import and only re-bundles what's
  // dirty. Templates aren't bundled (they're copied verbatim with a
  // header), so we fall back to fs.watch on the templates dir and
  // call buildTemplates() on any event there.
  const jsCtx = await esbuild.context(jsConfig);
  const cssCtx = await esbuild.context(cssConfig);
  await jsCtx.watch();
  await cssCtx.watch();

  buildTemplates();
  watch(join(SRC, "templates"), { recursive: false }, (_event, filename) => {
    if (!filename || !filename.endsWith(".html")) return;
    try {
      buildTemplates();
    } catch (err) {
      console.error("template rebuild failed:", err);
    }
  });

  console.log("watch mode — esbuild + fs.watch active. Ctrl-C to stop.");
  // Keep the process alive forever. Compose handles the lifecycle.
  await new Promise(() => {});
} else {
  await Promise.all([buildJs(), buildCss()]);
  buildTemplates();
  console.log("done.");
}
