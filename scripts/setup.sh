#!/usr/bin/env bash
# One-command setup for a BLOX PROTECTOR dev machine.
#   Run from the repo root:   ./scripts/setup.sh
#   (Windows: run it inside WSL or Git Bash — both come with bash.)
#
# It installs the game's tools (via Rokit) + the VS Code extensions, then tells you
# the couple of manual steps left. Safe to re-run any time.
set -e
cd "$(dirname "$0")/.."

echo "🧱  BLOX PROTECTOR — machine setup"
echo

# 1. Game tools (rojo, selene, stylua, luau-lsp) — pinned in rokit.toml
if command -v rokit >/dev/null 2>&1; then
	echo "→ Installing game tools via Rokit (rojo, selene, stylua, luau-lsp)…"
	rokit install
	echo "  ✓ tools installed"
else
	echo "✗ Rokit isn't installed yet — install it first, then re-run this script:"
	echo "    https://github.com/rojo-rbx/rokit#installation"
fi
echo

# 2. VS Code extensions (if the 'code' command is on PATH)
if command -v code >/dev/null 2>&1; then
	echo "→ Installing VS Code extensions…"
	for ext in JohnnyMorganz.luau-lsp Kampfkarren.selene-vscode JohnnyMorganz.stylua; do
		if code --install-extension "$ext" --force >/dev/null 2>&1; then
			echo "  ✓ $ext"
		else
			echo "  ⚠ couldn't install $ext — add it from the Extensions panel by hand"
		fi
	done
else
	echo "→ The 'code' command isn't on PATH. Install these 3 from VS Code's Extensions panel:"
	echo "    • Luau Language Server (JohnnyMorganz)"
	echo "    • Selene (Kampfkarren)"
	echo "    • StyLua (JohnnyMorganz)"
fi
echo

# 3. Sanity check the rest
echo "→ Checking the other tools you'll need:"
for tool in git node claude; do
	if command -v "$tool" >/dev/null 2>&1; then
		echo "  ✓ $tool"
	else
		echo "  ⚠ $tool not found (see docs/FAMILY_SETUP.md)"
	fi
done
echo

echo "✅  Almost there — last manual steps:"
echo "   1. In Roblox Studio, install the Rojo plugin (Toolbox → search \"Rojo\")."
echo "   2. Stamp your name on commits:  git config --global user.name \"YourName\""
echo "   3. Build: run  ./serve.sh  (then Connect in Studio), and  claude  in another terminal."
echo
echo "   Full guide → docs/FAMILY_SETUP.md   ·   Your track → docs/MILO.md or docs/XANDER.md"
