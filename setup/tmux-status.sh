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

