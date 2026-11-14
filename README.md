# Эталон VM для Claude Code

Один файл `bootstrap.sh` на чистом Debian 13 или Ubuntu Server 26.04 LTS поднимает машину, где Claude Code работает как отдельный непривилегированный пользователь `claude` и доступен владельцу через Remote Control (приложение Claude, вкладка Code).

Файл автономный: установщик и все файлы эталона лежат внутри него. С GitHub при установке ничего не скачивается. Файл можно взять со страницы репозитория (Download raw file) или перенести флешкой, `scp`, как угодно. Из сети берутся только пакеты ОС и Claude Code из репозитория Anthropic.

Сеть установщик не трогает: адрес, DNS и выход в интернет на машине должны уже работать. Изоляцию VM от локальной сети делайте на роутере (отдельная VLAN или правило «только интернет»): агенту видно всё, что видно машине.

Подробно: устройство, решения, проверка, частые проблемы — в [`docs/PROJECT.md`](docs/PROJECT.md).

## Установка копипастой (один блок)

На свежем Debian 13 или Ubuntu Server 26.04 LTS под своим пользователем вставьте блок **целиком**. Он создаёт `~/deploy.sh` и сразу его запускает: ставит `curl`, если его нет, скачивает `bootstrap.sh`, сверяет контрольную сумму и запускает установку. Ответы на вопросы установщика берутся с клавиатуры (`</dev/tty`), а не из вставленного текста. Без `sudo` (при установке Debian задан пароль root) войдите `su -` и вставьте тот же блок. Тот же скрипт лежит отдельным файлом: [`deploy.sh`](deploy.sh).

<!-- deploy-block:begin -->
```bash
cat > ~/deploy.sh <<'EOF'
#!/usr/bin/env bash
# Разворачивает эталон cc_golden на свежем Debian 13. Строку SHA= вписывает infra/build.sh.
# Запуск: bash ~/deploy.sh   (под своим пользователем с sudo, или под root после «su -»)
set -euo pipefail

# Репозиторий эталона: по умолчанию публичный эталон владельца; другой пользователь задаёт свой:
# CC_GOLDEN_REPO=ЛОГИН/РЕПО bash ~/deploy.sh
REPO=${CC_GOLDEN_REPO:-KTKSGN/cc_golden}
URL=https://raw.githubusercontent.com/$REPO/main/bootstrap.sh
SHA=41ffc501433ee816b5b5c30ea846df1a3c18571c68329ea936be7810eda8135a

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
EOF
bash ~/deploy.sh </dev/tty
```
<!-- deploy-block:end -->

## Установка и обновление

```
sudo bash bootstrap.sh --dry-run   # план без изменений
sudo bash bootstrap.sh
```

ОС определяется по `/etc/os-release`; `--os debian|ubuntu` задаёт её явно. Несовпадение ОС или неподдерживаемая версия останавливают установку. Существующий пользователь `ubuntu` сохраняется; создаётся только `claude`.

Файл кладите туда, где пишете только вы или root (не в `/home/claude`): иначе агент мог бы подменить код, который выполняется от root. Установщик это проверяет и останавливается.

Вопросов нет. Команда, меняющая систему, печатается перед выполнением. Существующий файл, если отличается, показывается diff'ом и заменяется только после «да», старый сохраняется как `.bak-<дата>`.

Обновление — новая версия `bootstrap.sh` и тот же запуск. Он не трогает `source/`, `memory/` и вход в Claude, а работающую службу агента не перезапускает: если нужно, скажет, какой командой это сделать.

## Что делает

1. Проверки: root, Debian 13 / Ubuntu Server 26.04 LTS, все файлы внутри на месте.
2. Пользователь `claude` без пароля и без sudo; папка `/home/claude/github`. Сразу после этого проверка, что `claude` не может менять сам `bootstrap.sh`.
3. Пакеты: `sudo curl git gnupg tmux auditd qemu-guest-agent podman uidmap passt openssh-client`.
4. Claude Code из apt-репозитория Anthropic (stable), ключ сверяется с отпечатком `31DDDE24DDFAB679F42D7BD2BAA929FF1A7ECACE`.
5. Правила агента в `/etc/claude-code/CLAUDE.md`.
6. Служба `claude-agent.service` (Claude Code в tmux, продолжает последний разговор), еженедельное обновление Claude Code `claude-code-update.timer`, скрипты в `~claude/.local/bin`.
7. Копия эталона в `/opt/claude-golden` (принадлежит root) и рабочая папка агента: `source/` и ссылка `infra` на эту копию.
8. Включение auditd, таймера и службы.
9. Самопроверка с отчётом PASS / FAIL.
10. В конце всегда блок «СДЕЛАЙТЕ РУКАМИ».

## Руками после установки

1. `sudo -u claude tmux attach -t claude` — выбрать тему, войти в аккаунт по ссылке, подтвердить доверие к папке. Выйти: Ctrl+B, затем D (не Ctrl+C и не exit).
2. `sudo reboot`, затем проверить: `systemctl is-active claude-agent.service` — `active`, в приложении появилась сессия `claude-<имя VM>`. В конце установки есть блок «Как этот экземпляр будет выглядеть у вас»: имя сессии, имя хоста, папка в памяти. Имя берётся из имени хоста; свое задайте до подключения памяти: `sudo hostnamectl set-hostname НОВОЕ_ИМЯ && sudo systemctl restart claude-agent.service`.
3. Подключить память — приватный репозиторий (можно попросить агента):
   `sudo -u claude -i claude-connect-memory git@github.com:ВЛАДЕЛЕЦ/РЕПО.git`
   Команда покажет ключ: добавьте его в репозиторий (Settings → Deploy keys, Allow write access).
4. Изолировать VM от локальной сети на роутере.

## Рабочая папка агента

```
/home/claude/github/
├── infra/    ссылка на /opt/claude-golden/infra: правила, служба, протоколы, пустые шаблоны (только чтение)
├── memory/   клон приватного репозитория памяти
└── source/   репозитории владельца с GitHub
```

`memory/` устроена так, чтобы одну память делили несколько VM: общее — в корне и `notes/`, своё у каждой машины — в `hosts/<имя VM>/` (журнал и обмен задачами с Claude в чате). Протокол — `infra/templates/memory/README.md`, он же попадает в `memory/README.md` при подключении пустого репозитория.

## Как устроен файл и как меняется эталон

`bootstrap.sh` — это `infra/install.sh`, за ним строка `exit 0`, метка `__INFRA_PAYLOAD__` и архив остальных файлов `infra/` (tar.gz в base64). При запуске установщик находит метку в себе и распаковывает архив во временную папку. Архив — только данные: bash дальше `exit 0` не читает.

Исходники — папка `infra/`, `bootstrap.sh` собирается из неё:

```
infra/build.sh           # пересобрать bootstrap.sh
infra/build.sh --check   # убедиться, что bootstrap.sh совпадает с infra/
```

Сборка воспроизводимая, `--check` сравнивает байты. После любой правки в `infra/` пересоберите и закоммитьте оба.

Агент пушит в этот репозиторий только в ветку `dev`. Ветка `main`, откуда берут `bootstrap.sh`, защищена: изменения в неё вливает владелец через Pull Request. Код из `main` выполняется от root на каждой машине, поэтому сюда попадает только то, что владелец посмотрел.

Секретов, ключей, паролей и адресов локальной сети в эталоне нет и быть не должно.

## Файлы

| В репозитории | На машине | Владелец, права |
|---|---|---|
| `bootstrap.sh` | где положили; не копируется | — |
| `infra/CLAUDE.md` | `/etc/claude-code/CLAUDE.md` | root, 644 |
| `infra/systemd/claude-agent.service` и `claude-agent.service.d/*.conf` | `/etc/systemd/system/` | root, 644 |
| `infra/systemd/claude-code-update.{service,timer}` | `/etc/systemd/system/` | root, 644 |
| `infra/bin/claude-agent-start`, `claude-rc`, `claude-connect-memory` | `/home/claude/.local/bin/` | claude, 755 |
| `infra/bin/agent-attach` | `/usr/local/bin/agent-attach` (подключение к единственной сессии claude, codex или gemini; jarvis — журнал заглушки) | root, 755 |
| `infra/profile/claude-alias.sh` | `/etc/profile.d/claude-alias.sh` (алиасы `claude`, `codex`, `gemini`, `jarvis`; настоящие программы: `command claude` и т.д.) | root, 644 |
| `infra/` целиком, кроме `install.sh` и `build.sh` | `/opt/claude-golden/infra/` | root, 755 |
