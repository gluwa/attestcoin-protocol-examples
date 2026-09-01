import fs from 'fs';
import path from 'path';
import dotenv from 'dotenv';

const REPO_ROOT = path.resolve(__dirname, '..');

export type Tutorial = 'bridge' | 'loan';

/**
 * Loads tutorial configuration into `process.env`.
 *
 * Config lives in the per-tutorial `bridge/.env` and `loan/.env`; the root `.env` is
 * optional and only fills in whatever the tutorial file leaves unset. A bare
 * `dotenv.config()` would instead resolve `.env` against `process.cwd()`, which misses
 * both tutorial files and depends on the directory the script happens to be run from.
 *
 * Precedence, highest first: shell/exported env, the tutorial's `.env`, the root `.env`.
 *
 * CI writes only the root `.env` and never creates the per-tutorial files, so passing a
 * tutorial stays correct there — the missing file is skipped.
 *
 * @param tutorials Which tutorials' `.env` to layer on top of the root one, lowest precedence
 *                  first. Omit to load only the root; pass several for utilities shared by
 *                  more than one tutorial.
 */
export function loadEnv(...tutorials: Tutorial[]): void {
  const shellEnv = { ...process.env };

  const files = [path.join(REPO_ROOT, '.env'), ...tutorials.map((t) => path.join(REPO_ROOT, t, '.env'))];

  for (const file of files) {
    if (fs.existsSync(file)) {
      dotenv.config({ path: file, override: true });
    }
  }

  // Anything the caller already exported outranks both files.
  for (const [key, value] of Object.entries(shellEnv)) {
    if (value !== undefined) {
      process.env[key] = value;
    }
  }
}
