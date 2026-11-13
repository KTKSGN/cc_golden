#!/usr/bin/env bash
# Разворачивает эталон cc_golden на свежем Debian 13. Строку SHA= вписывает infra/build.sh.
# Запуск: bash ~/deploy.sh   (под своим пользователем с sudo, или под root после «su -»)
set -euo pipefail

URL=https://raw.githubusercontent.com/KTKSGN/cc_golden/main/bootstrap.sh
SHA=6032b7dac8ca4494f6406c047773568ef3ff2b319c11017b5eb1e852fbdbd429

if [ "$(id -un)" = claude ]; then
  echo "Не запускайте под пользователем claude: это пользователь агента."; exit 1
fi
if [ "$(id -u)" -eq 0 ]; then
  SUDO=""
elif command -v sudo >/dev/null; then
  SUDO=sudo
else
  echo "sudo нет (при установке Debian задан пароль root). Войдите командой «su -» (с дефисом) и запустите: bash $0"; exit 1
fi

DIR="$HOME/cc_golden"
if ! command -v curl >/dev/null; then
  echo "== Ставлю curl"
  $SUDO apt-get update
  $SUDO env DEBIAN_FRONTEND=noninteractive apt-get install -y curl
fi

echo "== Скачиваю bootstrap.sh в $DIR"
mkdir -p "$DIR"
curl -fsSL -o "$DIR/bootstrap.sh" "$URL"

got="$(sha256sum "$DIR/bootstrap.sh" | cut -d' ' -f1)"
if [ "$got" != "$SHA" ]; then
  echo "Контрольная сумма НЕ совпала: $got"
  echo "Ожидалась:                   $SHA"
  echo "Установку не запускаю. Если эталон обновлялся, возьмите новую сумму и поправьте строку SHA= в этом скрипте."
  exit 1
fi
echo "== Контрольная сумма совпала, запускаю установку"
$SUDO bash "$DIR/bootstrap.sh"
