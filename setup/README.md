# Bash + tmux + Codex setup

This fork adds a pane-local `EN` / `中文` / `OFF` indicator and reads Codex's
visible Vim footer. Normal mode suspends Chinese input; Insert and Replace
restore your previous choice. `Ctrl+\` controls that choice. It wraps the Bash
session, so the same IME also works in other programs launched from that shell.

The installer enables Vim by default for new Codex sessions. Codex itself is
neither wrapped separately nor patched. There is no `codex-ime` command.

## Install on Linux

Install Rust/Cargo and Codex first. On Debian/Ubuntu, install the dependencies:

```bash
sudo apt install build-essential pkg-config librime-dev libclang-dev \
  rime-data-luna-pinyin nodejs tmux util-linux
git clone https://github.com/SGGb0nd/tui-ime.git
cd tui-ime
bash setup/install.sh
```

Use a terminal that supports the Kitty keyboard protocol, such as WezTerm.
tmux must support `extended-keys-format csi-u`. The script checks required
commands but leaves system dependency installation to you.

The build uses this checkout's locked dependencies. Other Linux distributions
need equivalent librime, Clang, Rime schema and OpenCC data packages. Custom
builds can supply `RIME_INCLUDE_DIR`, `RIME_LIB_DIR`, `LIBCLANG_PATH`,
`BINDGEN_EXTRA_CLANG_ARGS`, `LD_LIBRARY_PATH`, and `CARGO_TARGET_DIR`. If the
binaries need a custom library path at runtime, install launcher scripts in
`~/.local/bin` that export it, then use:

```bash
bash setup/install.sh --skip-build
```

`--skip-build` keeps existing `~/.local/bin/tui-ime{,-daemon}`. On the original
Rocky Linux installation, use this option to keep its user-local library
launchers. Those host-specific downloaded libraries and temporary build paths
are not part of this repository.

## What it configures

- Installs `tui-ime` and `tui-ime-daemon` to `~/.local/bin`, and integration
  scripts to `~/.local/share/tui-ime/setup`.
- Appends a managed source block to the end of `~/.bashrc`. Interactive Bash
  starts the daemon in a private tmux server and then starts the PTY proxy.
  Login mode, `PS1`, and `PROMPT_COMMAND` are carried into the wrapped shell;
  `TUI_IME_ACTIVE` prevents recursive wrapping.
- Adds a managed hook to `~/.tmux.conf`. It prefixes the current `status-right`
  with the active pane's IME state and extends its width. Repeated application
  does not add more prefixes. Existing prompt and status formatting stay in use.
- Sets `[tui] vim_mode_default = true` in `$CODEX_HOME/config.toml`, or
  `~/.codex/config.toml` when `CODEX_HOME` is unset. Other settings are preserved.
- Creates a simplified Luna Pinyin Rime customization only if there is no
  existing `default.custom.yaml`. Existing schemas and dictionaries stay intact.

Changed configuration files receive timestamped backups. Re-running the
installer updates its managed blocks. Keep the Bash block at the end of the
file, because successful startup uses `exec`. The original inline Bash block
is migrated only when it ends the file; otherwise the installer stops for you
to move it. Unusual inline or dotted TOML representations of the `tui` table
need conversion to a normal `[tui]` table before installation.

The daemon uses `~/.local/share/tui-ime/daemon.sock` and logs to
`~/.local/state/tui-ime/daemon.log`. Do not run a second systemd daemon against
the same socket. The private tmux server avoids requiring systemd user services.

## Activate and use

Open a new Bash terminal or tmux pane after installing. Existing wrappers keep
running their old executable until restarted. To reload the tmux hook:

```bash
tmux source-file ~/.tmux.conf
```

That command refreshes the indicator configuration only. Restarting the current
pane also loads the new proxy, but stops all programs running in that pane:

```bash
tmux respawn-pane -k -t "$TMUX_PANE" -c "$PWD" 'exec env -u TUI_IME_ACTIVE bash -l'
```

Toggle Chinese with `Ctrl+\`. In Codex, use `/vim` to toggle Vim mode for the
current session. New Codex sessions start with Vim enabled. `EN` means Chinese
interception is off (including Vim Normal); `中文` means it is on; `OFF` means
the daemon session is unavailable. The indicator describes proxy interception,
not Rime's internal ASCII switch.

`Ctrl+Shift+j` commits the highlighted candidate when composing Chinese, then
passes the newline shortcut to the application. In Codex Insert mode this
starts a new line. Unshifted `Ctrl+j` keeps your existing tmux pane-navigation
binding. The proxy preserves modifiers while a tmux client is foreground, so
the outer shell wrapper does not collapse these two shortcuts into one.

An old proxy around the SSH shell remains in memory after upgrading. Reconnect
SSH and reattach the existing tmux session to reload that outer wrapper; tmux
and its programs keep running. New panes load the updated inner wrapper.

Vim detection was exercised with Codex 0.161.0 in both default and
`--no-alt-screen` layouts, including resizing and returning to Bash. It reads
the displayed `Vim: Normal/Insert/Replace` label below the composer and checks
the foreground process is Codex via Linux `/proc`. The label must be visible;
this is not a Codex event API. If it is hidden or changes in a future release,
the proxy falls back to your manual IME choice.

## Disable integration

Remove the `BEGIN/END tui-ime Bash` block from `~/.bashrc` and the corresponding
tmux block from `~/.tmux.conf`, or restore the installer backups. Open a new
shell. Restore the previous Codex Vim setting if desired. To stop this setup's
daemon:

```bash
tmux -L tui-ime-backend kill-session -t daemon
```

Reloading a tmux config does not undo runtime options: restore your previous
`status-right`, width, and extended-key settings, or start a new tmux server.
User dictionaries under `~/.local/share/tui-ime/rime` are retained.
