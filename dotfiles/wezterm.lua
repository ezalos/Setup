-- ABOUTME: WezTerm terminal configuration with Nerd Font and Shift+Enter support.
-- ABOUTME: Optimized for Claude Code CLI usage.

local wezterm = require 'wezterm'
local config = wezterm.config_builder()

-- Font: MesloLGS NF (Nerd Font) with symbol and emoji fallbacks
config.font = wezterm.font_with_fallback({
  'MesloLGS NF',
  'Noto Sans Symbols2',
  'Noto Color Emoji',
})
config.font_size = 12.0

-- Dark purple background with 95% opacity (5% see-through)
config.window_background_opacity = 0.95
config.colors = {
  background = '#1a0a2e',
}

-- Window
config.window_padding = {
  left = 8,
  right = 8,
  top = 8,
  bottom = 8,
}

-- Scroll
config.scrollback_lines = 10000

-- Auto-tmux: each WezTerm window opens its own tmux session (w-MMDD-HHhMM)
-- Strips Cursor IDE AppImage paths from LD_LIBRARY_PATH before starting tmux,
-- because the tmux server inherits the environment of whoever started it first.
-- Cursor's bundled glibc breaks rustup's argv[0] detection (and possibly other tools).
config.default_prog = { '/bin/zsh', '-c', [[
  # Sanitize LD_LIBRARY_PATH: strip Cursor AppImage mount paths
  if [ -n "$LD_LIBRARY_PATH" ]; then
    cleaned=$(printf '%s' "$LD_LIBRARY_PATH" | tr ':' '\n' | grep -v '^$' | grep -v '\.mount_cursor' | paste -sd ':')
    [ -n "$cleaned" ] && export LD_LIBRARY_PATH="$cleaned" || unset LD_LIBRARY_PATH
  fi

  # If tmux server already exists, clean its global environment too
  if tmux has-session 2>/dev/null; then
    tmux set-environment -gu LD_LIBRARY_PATH 2>/dev/null
  fi

  sn="w-$(date +%m%d-%Hh%M)"
  if tmux has-session -t "$sn" 2>/dev/null; then
    i=2
    while tmux has-session -t "${sn}-${i}" 2>/dev/null; do ((i++)); done
    sn="${sn}-${i}"
  fi
  exec tmux new-session -s "$sn"
]] }

-- Key bindings: Shift+Enter sends CSI u sequence for Claude Code newline support
config.keys = {
  {
    key = 'Enter',
    mods = 'SHIFT',
    action = wezterm.action.SendString('\x1b[13;2u'),
  },
}

-- macOS only: Option+Arrow → shell word-nav (readline \eb/\ef), which tmux passes
-- through untouched. fn+Option+Arrow (= OPT+Home/End on Mac keyboards) → Meta+Arrow
-- sequence that tmux's bind -n M-Left/M-Right intercepts for pane switching.
-- On Linux, Alt+Arrow keeps its default Meta+Arrow sequence → tmux pane switch.
if wezterm.target_triple:find('darwin') then
  table.insert(config.keys, {
    key = 'LeftArrow',
    mods = 'OPT',
    action = wezterm.action.SendString('\x1bb'),
  })
  table.insert(config.keys, {
    key = 'RightArrow',
    mods = 'OPT',
    action = wezterm.action.SendString('\x1bf'),
  })
  table.insert(config.keys, {
    key = 'Home',
    mods = 'OPT',
    action = wezterm.action.SendString('\x1b[1;3D'),
  })
  table.insert(config.keys, {
    key = 'End',
    mods = 'OPT',
    action = wezterm.action.SendString('\x1b[1;3C'),
  })
end

return config
