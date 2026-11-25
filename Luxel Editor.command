#!/bin/zsh
# Double-click to open the Luxel level editor. When it closes, new floor art is imported into the game.
cd "$(dirname "$0")" || exit 1
GODOT=/Applications/Godot.app/Contents/MacOS/Godot
FLAG="$HOME/Library/Application Support/Godot/app_userdata/Luxel/editor/needs_import"
"$GODOT" --path . res://luxel/editor/editor.tscn >/dev/null 2>&1
if [[ -f "$FLAG" ]]; then
  echo "Saving your changes into the game..."
  while pgrep -f tools/epic/editor_paint.py >/dev/null; do sleep 1; done
  "$GODOT" --headless --path . --import >/dev/null 2>&1 && rm -f "$FLAG"
fi
echo "All saved. You can close this window."
