#!/usr/bin/env bash

## Sakurine's Rofi Launcher - Unified Launcher
## Theme: Sakurine (Transgender Pride)

MODE=${1:-drun}

case "$MODE" in
    drun|app|application)
        rofi -show drun -theme ~/.config/rofi/sakurine.rasi
        ;;
    window|win)
        rofi -show window -theme ~/.config/rofi/sakurine.rasi
        ;;
    *)
        echo "Usage: $0 {drun|window}"
        echo "  drun   - Application launcher"
        echo "  window - Window switcher"
        exit 1
        ;;
esac
