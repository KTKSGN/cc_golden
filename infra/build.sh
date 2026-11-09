#!/usr/bin/env bash
# Собирает автономный установщик ../bootstrap.sh: install.sh, за ним строка-метка
# и файлы infra/ (кроме install.sh и build.sh) как tar.gz в base64.
# Заодно вписывает контрольную сумму bootstrap.sh в ../deploy.sh (строка SHA=)
# и обновляет блок копипаста в ../README.md (между метками deploy-block).
#
#   infra/build.sh           собрать
#   infra/build.sh --check   проверить, что bootstrap.sh, deploy.sh и README совпадают с infra/
#
# Сборка воспроизводимая (порядок, даты, владельцы и права в архиве
# фиксированы), поэтому --check просто сравнивает байты.
set -euo pipefail

cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"

OUT=../bootstrap.sh
DEPLOY=../deploy.sh
README=../README.md

build() {
  cat install.sh
  printf '\n# Ниже встроенные файлы infra/, не редактировать: собирает infra/build.sh\nexit 0\n__INFRA_PAYLOAD__\n'
  tar --sort=name --mtime=@0 --owner=0 --group=0 --numeric-owner --mode=go-w \
    --exclude=./install.sh --exclude=./build.sh -cf - . | gzip -n -9 | base64 -w 76
}

# deploy.sh с контрольной суммой данного bootstrap.sh
deploy_with_sha() {  # deploy_with_sha SHA
  sed "s/^SHA=.*/SHA=$1/" "$DEPLOY"
}

# README с блоком копипаста, собранным из данного deploy.sh
readme_with_block() {  # readme_with_block ФАЙЛ_DEPLOY
  awk -v deploy="$1" '
    /^<!-- deploy-block:begin -->$/ {
      print
      print "```bash"
      print "cat > ~/deploy.sh <<'"'"'EOF'"'"'"
      while ((getline line < deploy) > 0) print line
      print "EOF"
      print "bash ~/deploy.sh </dev/tty"
      print "```"
      skip = 1; next
    }
    /^<!-- deploy-block:end -->$/ { skip = 0 }
    !skip { print }
  ' "$README"
}

case "${1:-}" in
  "")
    build >"$OUT.tmp"
    chmod 755 "$OUT.tmp"
    mv "$OUT.tmp" "$OUT"
    sha="$(sha256sum "$OUT" | cut -d' ' -f1)"
    deploy_with_sha "$sha" >"$DEPLOY.tmp" && chmod 755 "$DEPLOY.tmp" && mv "$DEPLOY.tmp" "$DEPLOY"
    readme_with_block "$DEPLOY" >"$README.tmp" && mv "$README.tmp" "$README"
    echo "собрано: bootstrap.sh ($(wc -c <"$OUT") байт)"
    echo "sha256: $sha (вписана в deploy.sh и README)"
    ;;
  --check)
    ok=1
    if ! cmp -s <(build) "$OUT"; then echo "bootstrap.sh устарел" >&2; ok=0; fi
    sha="$(sha256sum "$OUT" | cut -d' ' -f1)"
    if ! cmp -s <(deploy_with_sha "$sha") "$DEPLOY"; then echo "в deploy.sh не та контрольная сумма" >&2; ok=0; fi
    if ! cmp -s <(readme_with_block "$DEPLOY") "$README"; then echo "блок копипаста в README не совпадает с deploy.sh" >&2; ok=0; fi
    if [ "$ok" -eq 1 ]; then
      echo "bootstrap.sh, deploy.sh и README совпадают с infra/"
    else
      echo "запустите infra/build.sh и закоммитьте результат" >&2
      exit 1
    fi
    ;;
  *)
    echo "использование: $0 [--check]" >&2
    exit 2
    ;;
esac
