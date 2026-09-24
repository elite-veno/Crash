#!/bin/bash
# Tekent elk scherm en zet er een plaatje van neer, zodat je kunt zien hoe het eruitziet
# zonder Studio. Gebruik: bash tools/preview/alles.sh [map]
set -u
HIER="$(cd "$(dirname "$0")" && pwd)"
UIT="${1:-/tmp/claude-0/-home-user-Crash/8cf02fa5-02f3-5f7d-90b1-6865fc03a9c2/scratchpad/preview}"
SCRATCH="/tmp/claude-0/-home-user-Crash/8cf02fa5-02f3-5f7d-90b1-6865fc03a9c2/scratchpad"
mkdir -p "$UIT"
cd "$HIER"
python3 bundle.py > /dev/null || exit 1
for s in "${@:2}"; do :; done
SCHERMEN="${SCHERMEN:-home crash roulette tower mines plinko blackjack scratch wheel slots horse bus profile vip friends achievements}"
for s in $SCHERMEN; do
  if timeout 60 /tmp/claude-0/luaubin/luau dump.luau -a "$s" 2>/tmp/err.txt | tail -1 | python3 render.py > "/tmp/ui_$s.svg" 2>/dev/null && [ -s "/tmp/ui_$s.svg" ]; then
    node "$SCRATCH/svg2png.js" "/tmp/ui_$s.svg" "$UIT/$s.png" 2>/dev/null && echo "  $s ok" || echo "  $s PNG mislukt"
  else
    echo "  $s MISLUKT: $(head -2 /tmp/err.txt | tr '\n' ' ')"
  fi
done
