//! Read Codex's Vim footer from the reconstructed terminal screen.

pub(crate) const UNKNOWN: u8 = 0;
pub(crate) const NORMAL: u8 = 1;
pub(crate) const INSERT: u8 = 2;
pub(crate) const REPLACE: u8 = 3;

pub(crate) struct VimModeReader {
    parser: vt100::Parser,
    synchronized: bool,
    tail: Vec<u8>,
}

impl VimModeReader {
    pub(crate) fn new(rows: u16, cols: u16) -> Self {
        Self {
            parser: vt100::Parser::new(rows, cols, 0),
            synchronized: false,
            tail: Vec::new(),
        }
    }

    pub(crate) fn process(
        &mut self,
        bytes: &[u8],
        rows: u16,
        cols: u16,
        codex_foreground: bool,
    ) -> Option<u8> {
        if self.parser.screen().size() != (rows, cols) {
            self.parser.screen_mut().set_size(rows, cols);
        }
        self.parser.process(bytes);

        // Wait for complete synchronized redraws, including split escape sequences.
        let mut output = std::mem::take(&mut self.tail);
        output.extend_from_slice(bytes);
        for sequence in output.windows(8) {
            if sequence == b"\x1b[?2026h" {
                self.synchronized = true;
            } else if sequence == b"\x1b[?2026l" {
                self.synchronized = false;
            }
        }
        self.tail = output[output.len().saturating_sub(7)..].to_vec();
        if !codex_foreground {
            return Some(UNKNOWN);
        }
        if self.synchronized {
            return None;
        }

        let screen = self.parser.screen();
        let cursor_row = screen.cursor_position().0;
        // Codex's footer occupies up to two populated rows below the composer.
        // Some terminal configurations omit its colors, so use its location.
        let footers: Vec<_> = screen
            .rows(0, cols)
            .enumerate()
            .skip(cursor_row as usize + 1)
            .filter(|(_, line)| !line.trim().is_empty())
            .map(|(_, line)| line)
            .collect();
        Some(
            footers
                .into_iter()
                .rev()
                .take(2)
                .find_map(|footer| {
                    [
                        ("Vim: Normal", NORMAL),
                        ("Vim: Insert", INSERT),
                        ("Vim: Replace", REPLACE),
                    ]
                    .into_iter()
                    .find_map(|(label, mode)| footer.contains(label).then_some(mode))
                })
                .unwrap_or(UNKNOWN),
        )
    }
}
