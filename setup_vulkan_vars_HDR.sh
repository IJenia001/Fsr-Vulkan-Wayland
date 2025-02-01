#!/bin/bash
#
# Скрипт для настройки переменных окружения Vulkan и поддержки HDR
# Возможности:
#   1) Установка переменных для текущего пользователя в ~/.bashrc
#   2) Установка переменных для всех пользователей в /etc/environment
#   3) Проверка текущих переменных
#   4) Отмена изменений
#   5) Проверка поддержки HDR
#   6) Настройка HDR для Steam через Gamescope
#   7) Включение режима отладки

# === Настраиваемые значения переменных ===
VARS=(
  "AMD_VULKAN_FSR=1"
  "RADV_PERFTEST=aco,gpl,ngg"
  "RADV_DEBUG=zerovram"
  "DXVK_HDR=1"          # Для HDR в Wine/Proton
  "VK_EXT_HDR_METADATA=1" # Для метаданных HDR в Vulkan
)

# === Глобальные переменные ===
DEBUG=false

# === Функция для добавления переменных в ~/.bashrc ===
function setup_for_user() {
  local BASHRC_FILE="$HOME/.bashrc"
  check_file_exists "$BASHRC_FILE"

  echo ">>> Добавляем переменные в $BASHRC_FILE"
  backup_file "$BASHRC_FILE"

  for var in "${VARS[@]}"; do
    if ! grep -q "^export $var" "$BASHRC_FILE"; then
      echo "export $var" >> "$BASHRC_FILE"
      echo "  Добавлено: export $var"
    else
      echo "  Переменная уже есть: export $var"
    fi
  done

  echo ">>> Изменения внесены. Чтобы применить их сразу, выполните:"
  echo "source $BASHRC_FILE"
}

# === Функция для добавления переменных в /etc/environment ===
function setup_for_all_users() {
  local ENV_FILE="/etc/environment"
  check_root_permissions "$ENV_FILE"
  check_file_exists "$ENV_FILE"

  echo ">>> Добавляем переменные в $ENV_FILE"
  backup_file "$ENV_FILE"

  for var in "${VARS[@]}"; do
    key="${var%=*}"
    if ! grep -q "^$key=" "$ENV_FILE"; then
      echo "$var" >> "$ENV_FILE"
      echo "  Добавлено: $var"
    else
      echo "  Переменная уже существует: $key (проверьте $ENV_FILE вручную, если нужно изменить)"
    fi
  done

  echo ">>> Изменения внесены. Для активации лучше всего перезагрузить систему."
}

# === Функция для проверки текущих переменных ===
function check_current_vars() {
  echo ">>> Текущие значения переменных:"
  for var in "${VARS[@]}"; do
    key="${var%=*}"
    val=$(env | grep "^$key=" | cut -d'=' -f2-)
    echo "  $key: ${val:-не определена}"
  done
}

# === Функция для отмены изменений ===
function undo_changes() {
  echo ">>> Отмена изменений в ~/.bashrc"
  backup_file "$HOME/.bashrc"

  for var in "${VARS[@]}"; do
    sed -i "/^export $var/d" "$HOME/.bashrc"
    echo "  Удалена строка: export $var"
  done

  echo ">>> Переменные удалены. Чтобы применить изменения, перезагрузите сессию."
}

# === Функция для проверки поддержки HDR ===
function check_hdr_support() {
  echo ">>> Проверка поддержки HDR в системе..."
  echo "1. Проверка драйверов:"
  if lspci | grep -qi "AMD"; then
    echo "  Ваш GPU: AMD (драйвер AMDGPU поддерживает HDR)"
  elif lspci | grep -qi "NVIDIA"; then
    echo "  Ваш GPU: NVIDIA (требуется драйвер 565.57.01+ для корректной работы HDR)"
  else
    echo "  Не удалось определить поддержку HDR вашим GPU"
  fi

  echo "2. Проверка дисплея:"
  if xrandr --query | grep -qi "HDR"; then
    echo "  Ваш дисплей поддерживает HDR"
  else
    echo "  Ваш дисплей не поддерживает HDR"
  fi

  echo "3. Проверка драйверов и ПО:"
  if [ -n "$(glxinfo | grep -i 'renderer' | grep -i 'mesa')" ]; then
    echo "  Опознан Mesa драйвер"
    echo "  Для HDR в игры через Proton и Steam требуются:"
    echo "    * Mesa 23.3"
    echo "    * ваш дисплей и игры с поддержкой HDR"
    echo "    * команда запуска: STEAM_COMPAT_DATA_PATH=... %command% -force-gamemode"
  else
    echo "Неопознанный драйвер GPU. Вполне возможно поддержка HDR отсутствует"
  fi

  echo "4. Проверка Gamescope:"
  if command -v gamescope &> /dev/null; then
    echo "  Gamescope установлен (для HDR в Steam)"
  else
    echo "  Gamescope не установлен. ДляHDR в Steam установите gamescope и gamescope-session-steam"
  fi
}

# === Функция для настройки HDR в Steam через Gamescope ===
function setup_steam_hdr() {
  echo ">>> Настройка HDR для Steam через Gamescope"
  if [ ! -d "$HOME/.config/steam/steamrt/Config" ]; then
    mkdir -p "$HOME/.config/steam/steamrt/Config"
  fi

  local STEAM_CONFIG="$HOME/.config/steam/steamrt/Config/steamclient.ini"
  echo "[Steam]" > "$STEAM_CONFIG"
  echo "InBigPicture=1" >> "$STEAM_CONFIG"

  if [ ! -d "$HOME/.config/environment.d" ]; then
    mkdir -p "$HOME/.config/environment.d"
  fi

  local GAMESCOPE_CONFIG="$HOME/.config/environment.d/gamescope-session.conf"
  echo "if [ \"\$XDG_SESSION_DESKTOP\" = \"gamescope\" ]; then" > "$GAMESCOPE_CONFIG"
  echo "  SCREEN_WIDTH=3840" >> "$GAMESCOPE_CONFIG" # Задайте разрешение вашего дисплея
  echo "  SCREEN_HEIGHT=2160" >> "$GAMESCOPE_CONFIG"
  echo "  CONNECTOR=*,eDP-1" >> "$GAMESCOPE_CONFIG" # Задайте коннектор дисплея (проверьте с помощью xrandr --query)"
  echo "  CLIENTCMD=\"steam -gamepadui -pipewire-dmabuf\"" >> "$GAMESCOPE_CONFIG"
  echo "  GAMESCOPECMD=\"/usr/bin/gamescope --hdr-enabled --hdr-itm-enable \
  --hide-cursor-delay 3000 --fade-out-duration 200 --xwayland-count 2 \
  -W \$SCREEN_WIDTH -H \$SCREEN_HEIGHT -O \$CONNECTOR\"" >> "$GAMESCOPE_CONFIG"
  echo "fi" >> "$GAMESCOPE_CONFIG"

  echo ">>> Настройка завершена. Запустите Steam в режиме Big Picture для HDR"
}

# === Вспомогательные функции ===
function check_root_permissions() {
  if [[ $EUID -ne 0 ]]; then
    echo "Ошибка: для записи в $1 нужны права root."
    echo "Перезапустите скрипт с sudo или под root."
    exit 1
  fi
}

function check_file_exists() {
  if [[ ! -f "$1" ]]; then
    echo "Ошибка: файл $1 не найден."
    exit 1
  fi
}

function backup_file() {
  local FILE="$1"
  cp "$FILE" "$FILE.bak_$(date +%Y%m%d%H%M%S)"
}

function enable_debug_mode() {
  DEBUG=true
  echo ">>> Режим отладки активирован"
  set -x
}

# === Главное меню ===
function main_menu() {
  while true; do
    clear
    echo "=============================================="
    echo " Скрипт настройки Vulkan-переменных и HDR      "
    echo "=============================================="
    echo " 1) Установить переменные для текущего пользователя"
    echo " 2) Установить переменные для всех пользователей"
    echo " 3) Проверить текущие переменные"
    echo " 4) Отменить изменения"
    echo " 5) Проверить поддержку HDR"
    echo " 6) Настроить HDR для Steam (Gamescope)"
    echo " q) Выход"
    echo "----------------------------------------------"

    read -p "Выберите пункт меню: " choice

    case "$choice" in
      1)
        setup_for_user
        read -p "Нажмите Enter для продолжения"
        ;;
      2)
        setup_for_all_users
        read -p "Нажмите Enter для продолжения"
        ;;
      3)
        check_current_vars
        read -p "Нажмите Enter для продолжения"
        ;;
      4)
        undo_changes
        read -p "Нажмите Enter для продолжения"
        ;;
      5)
        check_hdr_support
        read -p "Нажмите Enter для продолжения"
        ;;
      6)
        setup_steam_hdr
        read -p "Нажмите Enter для продолжения"
        ;;
      q|Q)
        echo "Выход..."
        exit 0
        ;;
      *)
        echo "Неверный выбор. Попробуйте еще раз."
        sleep 2
        ;;
    esac
  done
}

# === Проверка аргументов ===
if [[ "$1" == "--debug" ]]; then
  enable_debug_mode
  shift
fi

# === Запуск меню ===
main_menu

exit 0
