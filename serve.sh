#!/usr/bin/env bash
# Dev server for the Mac mini (or any LAN machine) to connect to.
# Run on the MBP, then in Studio on the Mini: Rojo plugin → Connect → this machine's
# address (printed below) : 34872.
set -e
cd "$(dirname "$0")"
ADDR="$(scutil --get LocalHostName 2>/dev/null).local"
echo "Rojo serving on 0.0.0.0:34872 — connect Studio's Rojo plugin to:"
echo "   ${ADDR}:34872   (or  $(ipconfig getifaddr en0 2>/dev/null):34872 )"
exec rojo serve --address 0.0.0.0 --port 34872
