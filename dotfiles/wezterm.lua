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
config.default_prog = { '/bin/zsh', '-c', [[
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

return config
