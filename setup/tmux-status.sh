#!/usr/bin/env bash
# Add a pane-local indicator while preserving the configured status-right.
set -euo pipefail
tmux set-option -s extended-keys always
tmux set-option -s extended-keys-format csi-u
prefix='#{?@tui_ime_mode,#[fg=colour39][#{@tui_ime_mode}]#[default] ,}'
current=$(tmux show-options -gv status-right)
if [[ $current != "$prefix"* ]]; then
    tmux set-option -g status-right "$prefix$current"
    length=$(tmux show-options -gv status-right-length)
    tmux set-option -g status-right-length "$((length + 10))"
fi

# Navigator plugins may reserve Ctrl+J for moving to the pane below. Preserve
# their action outside Codex, but let Codex receive its newline shortcut.
binding=$(tmux list-keys -T root C-j 2>/dev/null || true)
if [[ -n $binding && $binding != *'codex-foreground.sh'* ]]; then
    fallback=$(printf '%s\n' "$binding" | sed -E 's/^bind-key[[:space:]]+(-r[[:space:]]+)?-T[[:space:]]+root[[:space:]]+C-j[[:space:]]+//')
    if [[ $fallback != "$binding" ]]; then
        tmux set-option -g @tui_ime_ctrl_j_fallback "$fallback"
        tmux bind-key -n C-j if-shell \
            'bash "$HOME/.local/share/tui-ime/setup/codex-foreground.sh" "#{pane_pid}"' \
            'send-keys C-j' "$fallback"
    fi
fi

