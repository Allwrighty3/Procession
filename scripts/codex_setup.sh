#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root"

if ! command -v elixir >/dev/null 2>&1; then
  echo "error: Elixir is not installed in this environment" >&2
  exit 1
fi

if ! command -v mix >/dev/null 2>&1; then
  echo "error: Mix is not installed in this environment" >&2
  exit 1
fi

export MIX_ENV="${MIX_ENV:-test}"
export HEX_HTTP_TIMEOUT="${HEX_HTTP_TIMEOUT:-120}"
export HEX_HTTP_CONCURRENCY="${HEX_HTTP_CONCURRENCY:-2}"

mix local.hex --force
mix local.rebar --force
mix deps.get
mix deps.compile
mix compile --warnings-as-errors

echo "Codex setup complete."
echo "Focused tests: mix test path/to/test_file.exs"
echo "Full suite:    mix test"
