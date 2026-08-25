#!/usr/bin/env node
"use strict";

const fs = require("node:fs");
const path = require("node:path");

const ROOT = path.resolve(__dirname, "..");
const DIST = path.join(ROOT, "dist");
const FILES = ["index.js", "router.js", "config.js", "errors.js", "logger.js", "package.json", "package-lock.json", "README.md"];
const DIRECTORIES = ["providers", "prompts", "schemas", "validators", "safety", "services"];
const MOCKS = ["memory_card_mock.json", "bottle_question_mock.json", "kitchen_dish_mock.json", "room_analysis_mock.json", "cross_memory_link_mock.json"];

fs.rmSync(DIST, { recursive: true, force: true });
fs.mkdirSync(DIST, { recursive: true });

for (const file of FILES) fs.copyFileSync(path.join(ROOT, file), path.join(DIST, file));
for (const directory of DIRECTORIES) fs.cpSync(path.join(ROOT, directory), path.join(DIST, directory), { recursive: true });

const mockSource = path.resolve(ROOT, "..", "mocks");
const mockTarget = path.join(DIST, "mocks");
fs.mkdirSync(mockTarget, { recursive: true });
for (const file of MOCKS) fs.copyFileSync(path.join(mockSource, file), path.join(mockTarget, file));

const forbidden = [".env", "node_modules", "tests"];
const paths = [];
function walk(directory) {
  for (const entry of fs.readdirSync(directory, { withFileTypes: true })) {
    const absolute = path.join(directory, entry.name);
    const relative = path.relative(DIST, absolute);
    paths.push(relative);
    if (entry.isDirectory()) walk(absolute);
  }
}
walk(DIST);
for (const token of forbidden) {
  if (paths.some((entry) => entry.split(path.sep).includes(token))) throw new Error(`部署包包含禁止路径: ${token}`);
}

const fileCount = paths.filter((entry) => !fs.statSync(path.join(DIST, entry)).isDirectory()).length;
console.log(`部署包已生成：${DIST}（${fileCount} 个文件）`);
