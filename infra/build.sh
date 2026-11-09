#!/usr/bin/env bash
# Собирает автономный установщик ../bootstrap.sh: install.sh, за ним строка-метка
# и файлы infra/ (кроме install.sh и build.sh) как tar.gz в base64.
#
#   infra/build.sh           собрать
#   infra/build.sh --check   проверить, что bootstrap.sh совпадает с infra/
#
# Сборка воспроизводимая (порядок, даты, владельцы и права в архиве
# фиксированы), поэтому --check просто сравнивает байты.
set -euo pipefail

cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"

OUT=../bootstrap.sh

build() {
  cat install.sh
  printf '\n# Ниже встроенные файлы infra/, не редактировать: собирает infra/build.sh\nexit 0\n__INFRA_PAYLOAD__\n'
  tar --sort=name --mtime=@0 --owner=0 --group=0 --numeric-owner --mode=go-w \
    --exclude=./install.sh --exclude=./build.sh -cf - . | gzip -n -9 | base64 -w 76
}

case "${1:-}" in
  "")
    build >"$OUT.tmp"
    chmod 755 "$OUT.tmp"
    mv "$OUT.tmp" "$OUT"
    echo "собрано: bootstrap.sh ($(wc -c <"$OUT") байт)"
    echo "sha256: $(sha256sum "$OUT" | cut -d' ' -f1)"
    ;;
  --check)
    if cmp -s <(build) "$OUT"; then
      echo "bootstrap.sh совпадает с infra/"
    else
      echo "bootstrap.sh устарел: запустите infra/build.sh и закоммитьте результат" >&2
      exit 1
    fi
    ;;
  *)
    echo "использование: $0 [--check]" >&2
    exit 2
    ;;
esac
