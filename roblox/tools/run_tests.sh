#!/bin/bash
# Typecheckt alle bron tegen de echte Roblox-API en draait daarna elke test met de losse
# Luau-uitvoerder. Beide werken zonder Studio.
set -u
LUAU=${LUAU:-/tmp/claude-0/luaubin/luau}
LSP=${LSP:-/tmp/claude-0/lspbin/luau-lsp}
cd "$(dirname "$0")/.."
fails=0

echo "=== sourcemap ==="
python3 tools/sourcemap.py

echo
echo "=== serverbestanden inpakken voor de tests ==="
python3 tools/bundle_server.py || fails=$((fails+1))

echo
echo "=== model voor Studio bouwen ==="
python3 tools/build_rbxmx.py || fails=$((fails+1))

echo
echo "=== kanalen tussen client en server ==="
python3 tools/check_channels.py || fails=$((fails+1))

echo
echo "=== typecheck tegen de Roblox-API ==="
if out=$("$LSP" analyze --definitions=tools/globalTypes.d.luau --sourcemap=sourcemap.json \
          --ignore='tools/**' --ignore='tests/server_sources.luau' \
          $(find src tests -name '*.luau' ! -name 'server_sources.luau' | sort) 2>&1); then
  echo "$out" | grep -v '^\[INFO\]' | grep -v '^$' || true
  echo "alle bestanden typechecken"
else
  echo "$out" | grep -v '^\[INFO\]' | head -25
  fails=$((fails+1))
fi

echo
echo "=== tests ==="
for f in $(find tests -name '*_test.luau' | sort); do
  printf '%-28s ' "$(basename "$f")"
  if out=$("$LUAU" "$f" 2>&1); then
    echo "PASS"; echo "$out" | sed 's/^/    /'
  else
    echo "FAIL"; echo "$out" | sed 's/^/    /'; fails=$((fails+1))
  fi
done

echo
if [ $fails -eq 0 ]; then echo "ALLES GROEN"; else echo "$fails PROBLEEM(EN)"; exit 1; fi
