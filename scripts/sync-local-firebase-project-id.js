#!/usr/bin/env node
// Brings the local Supabase database's app_config.firebase_project_id row in sync with
// SUPABASE_AUTH_FIREBASE_PROJECT_ID (.env at the repo root, see .env.example) after
// `supabase start` / `supabase db reset` — both re-run supabase/seed.sql, which always
// hardcodes the fake "balajiinfra-local-dev" value on purpose (plain SQL can't read OS
// env vars, and every pgTAP test's mocked JWT aud/iss depends on that literal). This
// script runs the sync as a separate step, after seeding, from outside the SQL file.
//
// In CI (and for any dev who hasn't set a real Firebase project id in .env), this is a
// no-op: the resolved value is the same "balajiinfra-local-dev" fixture already seeded,
// so pgTAP tests are unaffected. Run `npm run db:sync-firebase-project` again any time
// after switching the value in .env, or after any command that re-seeds the database.
"use strict";

const { execFileSync } = require("node:child_process");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");

const DEFAULT_PROJECT_ID = "balajiinfra-local-dev";
const ROOT = path.join(__dirname, "..");

function readProjectId() {
  if (process.env.SUPABASE_AUTH_FIREBASE_PROJECT_ID) {
    return process.env.SUPABASE_AUTH_FIREBASE_PROJECT_ID;
  }
  const envPath = path.join(ROOT, ".env");
  if (fs.existsSync(envPath)) {
    const match = fs
      .readFileSync(envPath, "utf8")
      .split(/\r?\n/)
      .find((line) => line.startsWith("SUPABASE_AUTH_FIREBASE_PROJECT_ID="));
    if (match) {
      const value = match.slice(match.indexOf("=") + 1).trim();
      if (value) return value;
    }
  }
  return DEFAULT_PROJECT_ID;
}

const projectId = readProjectId();
const escaped = projectId.replace(/'/g, "''");
const sql = `update public.app_config set value = to_jsonb('${escaped}'::text) where key = 'firebase_project_id';\n`;

const tmpFile = path.join(os.tmpdir(), `sync-firebase-project-id-${process.pid}.sql`);
fs.writeFileSync(tmpFile, sql, "utf8");

console.log(`Syncing local app_config.firebase_project_id -> "${projectId}"`);
if (projectId === DEFAULT_PROJECT_ID) {
  console.log("(matches the pgTAP fixture default — no-op for test purposes)");
}

try {
  execFileSync(
    process.platform === "win32" ? "npx.cmd" : "npx",
    ["supabase", "db", "query", "--local", "--file", tmpFile],
    { stdio: "inherit", cwd: ROOT },
  );
} finally {
  fs.unlinkSync(tmpFile);
}
