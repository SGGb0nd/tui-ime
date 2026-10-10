#!/usr/bin/env bash
# tmux sees tui-ime's outer PTY. Follow foreground groups across its inner PTY
# so key bindings can recognize Codex without matching background jobs.

codex_foreground() {
    local pid=$1 depth=$2 stat name child children_file
    local -a fields
    [[ $pid =~ ^[1-9][0-9]*$ && $depth -lt 16 ]] || return 1
    IFS= read -r stat 2>/dev/null < "/proc/$pid/stat" || return 1
    # comm can contain spaces and ')'; fields after the final ')' start at state.
    read -r -a fields <<< "${stat##*) }"
    [[ ${#fields[@]} -ge 6 && ${fields[4]} != 0 ]] || return 1
    [[ ${fields[0]} != T && ${fields[0]} != t && ${fields[0]} != Z ]] || return 1
    [[ ${fields[5]} =~ ^[1-9][0-9]*$ ]] || return 1

    if [[ ${fields[5]} != "$pid" ]]; then
        codex_foreground "${fields[5]}" "$((depth + 1))"
        return $?
    fi

    IFS= read -r name 2>/dev/null < "/proc/$pid/comm" || return 1
    [[ $name == codex ]] && return 0
    [[ $name == tui-ime ]] || return 1

    # Only tui-ime's child PTY session leaders are bridges to another terminal.
    # Do not descend through arbitrary children (such as background Codex).
    for children_file in /proc/"$pid"/task/*/children; do
        [[ -r $children_file ]] || continue
        for child in $(cat "$children_file" 2>/dev/null); do
            IFS= read -r stat 2>/dev/null < "/proc/$child/stat" || continue
            read -r -a fields <<< "${stat##*) }"
            [[ ${#fields[@]} -ge 6 && ${fields[1]} == "$pid" &&
               ${fields[3]} == "$child" && ${fields[4]} != 0 ]] || continue
            codex_foreground "$child" "$((depth + 1))" && return 0
        done
    done
    return 1
}

[[ $# == 1 ]] || exit 1
codex_foreground "$1" 0
