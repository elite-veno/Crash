#!/bin/bash
# Draait elke test in roblox/tests met de losse Luau-uitvoerder, en typecheckt alle bron.
set -u
LUAU=${LUAU:-/tmp/claude-0/luaubin/luau}
ANALYZE=${ANALYZE:-/tmp/claude-0/luaubin/luau-analyze}
cd "$(dirname "$0")/.."
fails=0

echo "=== typecheck ==="
for f in $(find src tests -name '*.luau' | sort); do
  if out=$("$ANALYZE" --formatter=plain "$f" 2>&1); then
    :
  else
    echo "FAIL typecheck $f"; echo "$out" | head -6; fails=$((fails+1))
  fi
done
[ $fails -eq 0 ] && echo "alle bestanden typechecken"

echo
echo "=== tests ==="
for f in $(find tests -name '*_test.luau' | sort); do
  printf '%-28s ' "$(basename "$f")"
  if out=$("$LUAU" "$f" 2>&1); then
    echo "PASS"
    echo "$out" | sed 's/^/    /'
  else
    echo "FAIL"; echo "$out" | sed 's/^/    /'; fails=$((fails+1))
  fi
done

echo
if [ $fails -eq 0 ]; then echo "ALLES GROEN"; else echo "$fails PROBLEEM(EN)"; exit 1; fi
