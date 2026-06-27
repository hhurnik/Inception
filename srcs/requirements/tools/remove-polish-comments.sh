#!/bin/sh
set -eu

# [EN] Only lines explicitly marked [PL] are removed; executable logic is not changed.
# [PL] Usuwane są wyłącznie linie jawnie oznaczone [PL]; logika wykonywalna nie jest zmieniana.
SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ROOT_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/../../.." && pwd)

find "$ROOT_DIR" -type f \
    \( -name 'Dockerfile' -o -name '*.sh' -o -name '*.yml' -o -name '*.yaml' -o -name '*.conf' -o -name '*.cnf' -o -name '*.template' -o -name '*.ini' -o -name '.env.example' -o -name 'Makefile' -o -name '.gitignore' -o -name '.dockerignore' \) \
    -exec sed -i '/^[[:space:]]*[#;][[:space:]]*\[PL\]/d' {} +

printf 'Removed [PL] educational comment lines. Review git diff before committing.\n'
