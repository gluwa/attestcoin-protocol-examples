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
 * @param tutorial Which tutorial's `.env` to layer on top of the root one; omit to load only the root.
 */
export function loadEnv(tutorial?: Tutorial): void {
  const shellEnv = { ...process.env };

  const files = [path.join(REPO_ROOT, '.env')];
  if (tutorial) {
    files.push(path.join(REPO_ROOT, tutorial, '.env'));
  }

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
