# Almanac

*Almanac — the nautical almanac, the navigator's book of dates and positions.*

Almanac lives in the menu bar and drops a perfectly formatted date into
whatever you're typing — one hotkey, any format, any time zone. It's in the
spirit of DateDrop: press ⌥⌘D and today's date lands at your cursor, already
shaped the way that document, commit message, or log entry wants it.

## Features

- Menu bar menu that renders the current date live in every saved format;
  click one to insert it into the frontmost app (hold ⌥ to copy instead).
- Global hotkey (default ⌥⌘D, recordable in Settings) inserts your first
  format wherever the cursor is. Optional per-format hotkeys for the first
  five formats.
- User-defined formats: Unicode date patterns, ISO 8601 with offset, or Unix
  timestamps — each with its own time zone (system, UTC, or any named zone
  via a searchable picker) and an optional day offset (tomorrow, +N days).
- Sensible defaults out of the box: `2026-07-19`, `July 19, 2026`,
  `Sat, Jul 19`, `2026-07-19 14:32 PDT`, ISO 8601, Unix timestamp.
- Settings window to add, edit, reorder, and delete formats, with a live
  preview that ticks every second.
- "Pick a Date…" window (calendar + time) to insert or copy any format
  rendered at a moment other than now.
- Insertion works by briefly borrowing the clipboard: it saves what's there,
  pastes the date with a synthesized ⌘V, and restores the old contents after
  a beat. A copy-only mode is available if you'd rather skip Accessibility.
- Formats and preferences persist as JSON in
  `~/Library/Application Support/Almanac/`.

## Build

```sh
./make-app.sh
```

Builds a release binary, generates the icon, assembles `Almanac.app`, and
installs it to `/Applications`.

## Permissions

- **Accessibility** — required only for paste-at-cursor. macOS lets an app
  synthesize keystrokes (the ⌘V that performs the insert) only when it has
  been granted Accessibility in System Settings → Privacy & Security →
  Accessibility. Settings → General has a button that jumps straight there.
  Without the grant, Almanac quietly falls back to copying the date to the
  clipboard so you can paste it yourself — nothing breaks.

## Not yet

- Per-format hotkeys register for the first five formats only.
- Clipboard restore is best-effort: standard pasteboard data types round-trip,
  but exotic promised/lazy clipboard content may not survive the swap.
- The hotkey recorder labels keys by US ANSI key codes, so a recorded key may
  display differently on non-US layouts.
