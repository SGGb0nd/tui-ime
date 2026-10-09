# Source at the END of ~/.bashrc: successful startup execs the proxy.
if [[ $- == *i* && -z ${TUI_IME_ACTIVE:-} && -t 0 && -t 1 \
      && -x "$HOME/.local/bin/tui-ime" ]]; then
    export TUI_IME_SOCKET="$HOME/.local/share/tui-ime/daemon.sock"
    mkdir -p "$HOME/.local/state/tui-ime"
    (
        flock -w 10 9 || exit 1
        if ! tmux -L tui-ime-backend has-session -t daemon 2>/dev/null; then
            tmux -L tui-ime-backend new-session -d -s daemon \
                'exec "$HOME/.local/bin/tui-ime-daemon" >> "$HOME/.local/state/tui-ime/daemon.log" 2>&1' \
                9>&- || exit 1
        fi
        for attempt in {1..50}; do
            if [[ -S "$TUI_IME_SOCKET" ]] && node -e '
                const c = require("net").createConnection(process.env.TUI_IME_SOCKET);
                c.on("connect", () => { c.end(); process.exit(0); });
                c.on("error", () => process.exit(1));
                setTimeout(() => process.exit(1), 500).unref();
            ' 2>/dev/null; then
                exit 0
            fi
            sleep 0.1
        done
        exit 1
    ) 9>"$HOME/.local/state/tui-ime/start.lock"
    if [[ $? == 0 ]]; then
        if [[ -n ${TMUX:-} ]]; then
            bash "$HOME/.local/share/tui-ime/setup/tmux-status.sh"
        fi
        export PS1 PROMPT_COMMAND
        if shopt -q login_shell; then
            exec "$HOME/.local/bin/tui-ime" -- /bin/bash --login -i
        else
            exec "$HOME/.local/bin/tui-ime" -- /bin/bash -i
        fi
    else
        printf 'tui-ime daemon unavailable; see ~/.local/state/tui-ime/daemon.log\n' >&2
    fi
fi

