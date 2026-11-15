#!/usr/bin/env bash
# Phantom Launcher for Linux. Saves settings to phantom.ini and starts
# the client with the right environment variables.
set -euo pipefail

dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ini="$dir/phantom.ini"

mode=infinite
stars=999999
ton=13370
transfer=25
telegram=""

if [[ -f "$ini" ]]; then
  while IFS='=' read -r key value; do
    [[ -z "$key" || "$key" == \#* ]] && continue
    case "$key" in
      Mode) mode="$value" ;;
      Stars) stars="$value" ;;
      Ton) ton="$value" ;;
      TransferStars) transfer="$value" ;;
      TelegramPath) telegram="$value" ;;
    esac
  done < "$ini"
fi

find_telegram() {
  local candidate
  for candidate in \
    "$dir/Telegram" \
    "$dir/Telegram-phantom-linux-x64" \
    "$dir/../Telegram" \
    "$dir/../Telegram-phantom-linux-x64" \
    "$dir/../tdesktop/out/bin/Telegram"; do
    if [[ -x "$candidate" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done
  return 1
}

if [[ -z "$telegram" || ! -x "$telegram" ]]; then
  telegram="$(find_telegram || true)"
fi

save() {
  cat > "$ini" <<EOF
# Phantom Launcher settings
Mode=$mode
Stars=$stars
Ton=$ton
TransferStars=$transfer
TelegramPath=$telegram
EOF
}

if command -v zenity >/dev/null 2>&1; then
  mode="$(zenity --list --title='Phantom Launcher' --text='Режим валюты' \
    --radiolist --column='' --column='Режим' \
    $([[ "$mode" == infinite ]] && echo TRUE || echo FALSE) 'Бесконечная' \
    $([[ "$mode" == spend ]] && echo TRUE || echo FALSE) 'Траты' \
    2>/dev/null)" || exit 0
  [[ "$mode" == 'Бесконечная' ]] && mode=infinite || mode=spend
  stars="$(zenity --entry --title='Phantom Launcher' --text='Звёзды на балансе' --entry-text="$stars")" || exit 0
  ton="$(zenity --entry --title='Phantom Launcher' --text='Грамы (TON) на балансе' --entry-text="$ton")" || exit 0
  transfer="$(zenity --entry --title='Phantom Launcher' --text='Цена передачи NFT, звёзд' --entry-text="$transfer")" || exit 0
  if [[ -z "$telegram" || ! -x "$telegram" ]]; then
    telegram="$(zenity --file-selection --title='Выберите Telegram' 2>/dev/null)" || exit 0
  fi
else
  echo "Telegram: ${telegram:-не найден}"
  read -r -p "Режим [1] бесконечная / [2] траты (сейчас: $mode): " choice || true
  [[ "$choice" == 2 ]] && mode=spend
  read -r -p "Звёзды на балансе [$stars]: " input || true
  [[ -n "$input" ]] && stars="$input"
  read -r -p "Грамы (TON) на балансе [$ton]: " input || true
  [[ -n "$input" ]] && ton="$input"
  read -r -p "Цена передачи NFT, звёзд [$transfer]: " input || true
  [[ -n "$input" ]] && transfer="$input"
  if [[ -z "$telegram" || ! -x "$telegram" ]]; then
    read -r -p "Путь к Telegram: " telegram || true
  fi
fi

if [[ -z "$telegram" || ! -x "$telegram" ]]; then
  echo "Telegram не найден." >&2
  exit 1
fi

save

export TD_FAKE_ECONOMY=1
export TD_FAKE_STARS="$stars"
export TD_FAKE_TON="$ton"
export TD_FAKE_TRANSFER_STARS="$transfer"
if [[ "$mode" == infinite ]]; then
  export TD_FAKE_INFINITE=1
else
  unset TD_FAKE_INFINITE
fi

cd -- "$(dirname -- "$telegram")"
exec "$telegram"
