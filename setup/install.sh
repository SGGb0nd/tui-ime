#!/usr/bin/env bash
# Install this fork and its Bash/tmux/Codex integration without sudo.
set -euo pipefail

setup_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source_dir=$(dirname -- "$setup_dir")
skip_build=false
case ${1:-} in
    '') ;;
    --skip-build) skip_build=true ;;
    *) printf 'Usage: %s [--skip-build]\n' "$0" >&2; exit 2 ;;
esac

for command_name in node tmux flock; do
    command -v "$command_name" >/dev/null || {
        printf 'Required command missing: %s (see setup/README.md)\n' "$command_name" >&2
        exit 1
    }
done

install_dir="$HOME/.local/share/tui-ime/setup"
mkdir -p "$HOME/.local/bin" "$install_dir" "$HOME/.local/state/tui-ime"
if ! "$skip_build"; then
    command -v cargo >/dev/null || { printf 'Install Rust first.\n' >&2; exit 1; }
    (cd "$source_dir" && cargo build --release --locked --bin tui-ime --bin tui-ime-daemon)
    target_dir=${CARGO_TARGET_DIR:-"$source_dir/target"}
    [[ $target_dir == /* ]] || target_dir="$source_dir/$target_dir"
    for binary_name in tui-ime tui-ime-daemon; do
        # Atomic replacement allows existing wrappers to keep running.
        install -m755 "$target_dir/release/$binary_name" "$HOME/.local/bin/$binary_name.new"
        mv -f "$HOME/.local/bin/$binary_name.new" "$HOME/.local/bin/$binary_name"
    done
fi
for binary_name in tui-ime tui-ime-daemon; do
    [[ -x "$HOME/.local/bin/$binary_name" ]] || {
        printf 'Missing ~/.local/bin/%s; build first.\n' "$binary_name" >&2
        exit 1
    }
done
for asset_name in bash.sh tmux-status.sh configure.mjs; do
    install -m644 "$setup_dir/$asset_name" "$install_dir/$asset_name"
done
node "$install_dir/configure.mjs"
if [[ -n ${TMUX:-} ]]; then
    bash "$install_dir/tmux-status.sh"
fi
printf 'Installed. Open a new Bash terminal or tmux pane to activate.\n'

