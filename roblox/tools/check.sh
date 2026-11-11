#!/usr/bin/env bash
# The five merge checks (docs/ARCHITECTURE.md): Selene, StyLua, the Lune specs, `rojo build`
# and luau-lsp. Run from anywhere: `bash roblox/tools/check.sh`. Prints one line per check
# and the tail of any failure; exits non-zero if one fails.
#
# A fresh worktree needs two things first (both gitignored):
#   - `wally install` in roblox/ (Packages/, ServerPackages/)
#   - build/globalTypes.d.luau (copy it from another checkout, or see roblox/README.md)
export PATH="$HOME/.rokit/bin:$PATH"
cd "$(dirname "$0")/.." || exit 2
mkdir -p build
fail=0
run() { # name, command...
	local name="$1"
	shift
	local out
	out=$("$@" 2>&1)
	local rc=$?
	if [ $rc -eq 0 ]; then
		echo "PASS $name :: $(echo "$out" | tail -1 | cut -c1-160)"
	else
		echo "FAIL $name (rc=$rc)"
		echo "$out" | tail -"${TAILN:-25}"
		fail=1
	fi
}
run selene selene src tests
run stylua stylua --check src tests
run lune lune run tests/run.luau
run rojo-build rojo build -o build/test.rbxl
run sourcemap rojo sourcemap default.project.json -o sourcemap.json
run luau-lsp luau-lsp analyze --sourcemap=sourcemap.json --definitions=build/globalTypes.d.luau --ignore="Packages/**" --ignore="ServerPackages/**" src
exit $fail
