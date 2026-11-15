# cc-watchdog (образец для будущего watchdog микроядра)

Сторожевой таймер сессии Claude Code в tmux. Только для Claude Code.

- heartbeat: таймер задач внутри сессии (cron) в начале каждого срабатывания делает `touch ~/.local/state/cc-watchdog/heartbeat`. Cron срабатывает только пока сессия свободна, поэтому устаревший heartbeat = сессия занята окном или зависла.
- проверка: пользовательский таймер systemd `cc-watchdog.timer` раз в 5 мин запускает `~/.local/bin/cc-watchdog`.
- условие действия: heartbeat старше STALE_S (30 мин) И окно tmux молчит дольше IDLE_S (10 мин) — иначе идёт работа, не трогаем.
- пропуск: на экране вопрос владельцу (Do you want to, (y/n) и т.п.) — клавишу не жмём.
- действие: клавиша Escape в окно `claude:0.0`; не чаще раза в COOLDOWN_S; после MAX_ACTIONS нажатий без ответа — файл `~/.local/state/cc-watchdog/ALERT` и остановка.
- журнал: `~/.local/state/cc-watchdog/watchdog.log`. Проверка без нажатия: `cc-watchdog --dry-run`.

Установка у агента: скопировать `bin/cc-watchdog` в `~/.local/bin`, шаблон в `~/.config/cc-watchdog/watchdog.conf`, юниты в `~/.config/systemd/user/`, `systemctl --user enable --now cc-watchdog.timer` (нужен linger). Вшивание в install.sh/bootstrap — отдельным шагом, после ревью владельца.

Перенос в Jarvis: те же четыре роли (heartbeat → проверка → действие → эскалация), цель — не tmux-окно, а процесс/модель, действие — прерывание/перезапуск, эскалация — уведомление.
