// Update only the integration blocks and Vim default; preserve other settings.
import fs from 'node:fs';
import path from 'node:path';
import os from 'node:os';

const home = os.homedir();
const stamp = new Date().toISOString().replace(/[:.]/g, '-');
const read = file => fs.existsSync(file) ? fs.readFileSync(file, 'utf8') : '';
function write(file, before, after) {
    if (before === after) return;
    fs.mkdirSync(path.dirname(file), { recursive: true });
    if (fs.existsSync(file)) fs.copyFileSync(file, `${file}.before-tui-ime-${stamp}`);
    const mode = fs.existsSync(file) ? fs.statSync(file).mode & 0o777 : 0o600;
    const temporary = `${file}.tui-ime-new`;
    fs.writeFileSync(temporary, after, { mode });
    fs.renameSync(temporary, file);
    console.log(`Updated ${file}`);
}
function block(text, name, body) {
    const start = `# BEGIN tui-ime ${name}`;
    const end = `# END tui-ime ${name}`;
    const value = `${start}\n${body}\n${end}\n`;
    const first = text.indexOf(start);
    if (first === -1) return `${text}${text.endsWith('\n') || !text ? '' : '\n'}\n${value}`;
    const last = text.indexOf(end, first);
    if (last === -1) throw new Error(`Unclosed integration block: ${name}`);
    const after = last + end.length + (text[last + end.length] === '\n' ? 1 : 0);
    return text.slice(0, first) + value + text.slice(after);
}

const bashFile = path.join(home, '.bashrc');
const bashBefore = read(bashFile);
let bashText = bashBefore;
// Migrate the inline block used by this fork's initial installation, only at EOF.
const legacy = '# tui-ime: wrap interactive Bash sessions, preserving their login mode and prompt.';
const legacyAt = bashText.indexOf(legacy);
if (legacyAt !== -1) {
    const remainder = bashText.slice(legacyAt);
    const closing = /^fi\r?$/m.exec(remainder);
    if (!remainder.startsWith(`${legacy}\nif [[`) || !closing ||
        remainder.slice(closing.index + closing[0].length).trim()) {
        throw new Error('Move the legacy tui-ime block to the end of .bashrc before installing.');
    }
    bashText = bashText.slice(0, legacyAt);
}
bashText = block(bashText, 'Bash', '[ -r "$HOME/.local/share/tui-ime/setup/bash.sh" ] && source "$HOME/.local/share/tui-ime/setup/bash.sh"');

const tmuxFile = path.join(home, '.tmux.conf');
const tmuxBefore = read(tmuxFile);
const tmuxText = block(tmuxBefore, 'tmux', 'run-shell \'bash "$HOME/.local/share/tui-ime/setup/tmux-status.sh"\'');

const codexFile = path.join(process.env.CODEX_HOME || path.join(home, '.codex'), 'config.toml');
const codexBefore = read(codexFile);
let codexText = codexBefore;
const table = /^\[tui\][ \t]*(?:#.*)?\r?$/m.exec(codexText);
if (table) {
    const begin = table.index + table[0].length;
    const following = /^\s*\[/m.exec(codexText.slice(begin));
    const end = following ? begin + following.index : codexText.length;
    let section = codexText.slice(begin, end);
    if (/^\s*vim_mode_default\s*=/m.test(section)) {
        section = section.replace(/^[ \t]*vim_mode_default\s*=.*$/m, 'vim_mode_default = true');
    } else {
        section = `\nvim_mode_default = true${section}`;
    }
    codexText = codexText.slice(0, begin) + section + codexText.slice(end);
} else {
    if (/^\s*(?:tui\s*=|tui\.vim_mode_default\s*=)/m.test(codexText)) {
        throw new Error('Inline/dotted tui configuration found; set vim_mode_default manually before installing.');
    }
    codexText += `${codexText.endsWith('\n') || !codexText ? '' : '\n'}\n[tui]\nvim_mode_default = true\n`;
}

const rimeFile = path.join(home, '.local/share/tui-ime/rime/default.custom.yaml');
const rimeBefore = read(rimeFile);
// Existing Rime customization is owned by the user.
if (!fs.existsSync(rimeFile)) {
    write(rimeFile, rimeBefore, 'patch:\n  schema_list:\n    - schema: luna_pinyin_simp\n  menu/page_size: 5\n');
}
write(bashFile, bashBefore, bashText);
write(tmuxFile, tmuxBefore, tmuxText);
write(codexFile, codexBefore, codexText);
