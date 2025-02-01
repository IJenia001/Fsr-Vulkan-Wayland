#!/bin/bash
#
# Улучшенный скрипт для настройки Vulkan и HDR с расширенной функциональностью

# === Настраиваемые значения переменных ===
VARS=(
  "AMD_VULKAN_FSR=1"
  "RADV_PERFTEST=aco,gpl,ngg"
  "RADV_DEBUG=zerovram"
  "DXVK_HDR=1"
  "VK_EXT_HDR_METADATA=1"
)

# === Глобальные переменные ===
DEBUG=false
LOG_FILE="/tmp/vulkan_hdr_setup_$(date +%Y%m%d).log"
DETECTED_SHELL=$(basename "$SHELL")
CONFIG_FILES=()

# === Инициализация ===
function init_script() {
  check_dependencies
  check_environment
  validate_vars
  detect_config_files
}

# === Логирование ===
function log() {
  local message="[$(date '+%Y-%m-%d %H:%M:%S')] $*"
  echo "$message" | tee -a "$LOG_FILE"
}

# === Проверка зависимостей ===
function check_dependencies() {
  local deps=("xrandr" "glxinfo" "lspci" "bc")
  local missing=()
  
  for dep in "${deps[@]}"; do
    if ! command -v "$dep" &> /dev/null; then
      missing+=("$dep")
    fi
  done

  if [ ${#missing[@]} -gt 0 ]; then
    log "Отсутствующие зависимости: ${missing[*]}"
    read -p "Установить недостающие пакеты? [y/N] " answer
    if [[ "$answer" =~ [yY] ]]; then
      sudo apt install -y "${missing[@]}" || {
        log "Ошибка установки пакетов"; exit 1
      }
    else
      log "Прерывание: требуемые зависимости не установлены"
      exit 1
    fi
  fi
}

# === Определение конфигурационных файлов ===
function detect_config_files() {
  case "$DETECTED_SHELL" in
    "bash")  CONFIG_FILES=("$HOME/.bashrc") ;;
    "zsh")   CONFIG_FILES=("$HOME/.zshrc") ;;
    *)       CONFIG_FILES=("$HOME/.profile") ;;
  esac
}

# === Валидация переменных ===
function validate_vars() {
  for var in "${VARS[@]}"; do
    if [[ ! "$var" =~ ^[A-Za-z_][A-Za-z0-9_]*=.*$ ]]; then
      log "Некорректная переменная: $var"
      exit 1
    fi
  done
}

# === Проверка окружения ===
function check_environment() {
  log "Проверка окружения..."
  if [[ "$XDG_SESSION_TYPE" == "wayland" ]]; then
    log "Обнаружен Wayland. Некоторые функции могут работать иначе."
  fi
}

# === Основные функции ===

# Установка для текущего пользователя
function setup_for_user() {
  for config in "${CONFIG_FILES[@]}"; do
    local config_file="$config"
    check_file_exists "$config_file"
    backup_file "$config_file"
    
    log "Добавление переменных в $config_file"
    for var in "${VARS[@]}"; do
      if ! grep -q "^export $var" "$config_file"; then
        echo "export $var" >> "$config_file"
        log "Добавлено: export $var"
      else
        log "Переменная уже существует: export $var"
      fi
    done
  done
  
  echo -e "\033[1;32mГотово!\033[0m Примените изменения командой: source ${CONFIG_FILES[0]}"
}

# Установка для всех пользователей
function setup_for_all_users() {
  local ENV_FILE="/etc/environment"
  check_root_permissions "$ENV_FILE"
  check_file_exists "$ENV_FILE"
  
  local TMP_FILE=$(mktemp)
  cp "$ENV_FILE" "$TMP_FILE"
  
  log "Редактирование $ENV_FILE"
  for var in "${VARS[@]}"; do
    key="${var%=*}"
    if ! grep -q "^$key=" "$TMP_FILE"; then
      echo "$var" >> "$TMP_FILE"
      log "Добавлено: $var"
    fi
  done

  if env -i bash -c "set -a && source $TMP_FILE && env"; then
    sudo mv "$TMP_FILE" "$ENV_FILE"
    log "Файл $ENV_FILE успешно обновлен"
  else
    log "Ошибка валидации. Отмена изменений."
    rm "$TMP_FILE"
    exit 1
  fi
  
  echo -e "\033[1;32mГотово!\033[0m Требуется перезагрузка системы."
}

# Проверка текущих переменных
function check_current_vars() {
  echo -e "\n\033[1;36mТекущие переменные окружения:\033[0m"
  for var in "${VARS[@]}"; do
    key="${var%=*}"
    value=$(printenv "$key" || echo "не установлена")
    printf "  %-25s = %s\n" "$key" "$value"
  done
}

# Отмена изменений
function undo_changes() {
  PS3="Выберите файл для отката: "
  select file in "Пользовательские" "Системные" "Выход"; do
    case $file in
      "Пользовательские")
        for config in "${CONFIG_FILES[@]}"; do
          backup_file "$config"
          for var in "${VARS[@]}"; do
            sed -i "/^export $var/d" "$config"
          done
          log "Изменения в $config отменены"
        done
        ;;
      "Системные")
        sudo sed -i "/^$(echo "${VARS[@]}" | sed 's/ /\|^/g')/d" /etc/environment
        log "Изменения в /etc/environment отменены"
        ;;
      "Выход") return ;;
      *) echo "Неверный выбор" ;;
    esac
    break
  done
}

# Проверка HDR
function check_hdr_support() {
  echo -e "\n\033[1;36mПроверка поддержки HDR:\033[0m"
  
  # Проверка GPU
  echo -e "\033[1;33m[1/4] Аппаратная поддержка:\033[0m"
  if lspci | grep -qi "NVIDIA"; then
    nvidia_version=$(nvidia-smi --query-gpu=driver_version --format=csv,noheader,nounits | head -n1)
    if (( $(echo "$nvidia_version >= 565.57" | bc -l) )); then
      echo "  NVIDIA: версия $nvidia_status"
    else
      echo "  NVIDIA: требуется драйвер 565.57+"
    fi
  elif lspci | grep -qi "AMD"; then
    echo "  AMD: поддерживается начиная с Mesa 23.3"
  fi

  # Проверка дисплея
  echo -e "\033[1;33m[2/4] Проверка дисплея:\033[0m"
  xrandr --query | grep -qi "HDR" && hdr_status="Да" || hdr_status="Нет"
  echo "  HDR поддержка: $hdr_status"

  # Проверка ПО
  echo -e "\033[1;33m[3/4] Программная поддержка:\033[0m"
  mesa_version=$(glxinfo | grep "OpenGL core profile version" | grep -oP '\d+\.\d+')
  echo "  Версия Mesa: ${mesa_version:-не определена}"
  
  # Проверка Gamescope
  echo -e "\033[1;33m[4/4] Проверка Gamescope:\033[0m"
  if command -v gamescope &> /dev/null; then
    gamescope --help | grep -q -- --hdr-enabled && \
    echo "  Версия поддерживает HDR" || echo "  Версия не поддерживает HDR"
  else
    echo "  Gamescope не установлен"
  fi
}

# Настройка Steam HDR
function setup_steam_hdr() {
  if ! command -v steam &> /dev/null; then
    log "Steam не установлен!"
    return 1
  fi

  local CONNECTOR=$(xrandr --query | grep " connected" | cut -d' ' -f1 | head -n1)
  local RESOLUTION=$(xrandr --query | grep -oP '\d+x\d+' | head -n1)
  
  # Настройка Steam
  local STEAM_CONFIG_DIR="$HOME/.config/steam/steamrt/Config"
  mkdir -p "$STEAM_CONFIG_DIR"
  echo -e "[Steam]\nInBigPicture=1" > "$STEAM_CONFIG_DIR/steamclient.ini"

  # Настройка Gamescope
  local GAMESCOPE_CONFIG="$HOME/.config/environment.d/gamescope-session.conf"
  cat > "$GAMESCOPE_CONFIG" << EOF
if [ "\$XDG_SESSION_DESKTOP" = "gamescope" ]; then
  SCREEN_WIDTH=${RESOLUTION%x*}
  SCREEN_HEIGHT=${RESOLUTION#*x}
  CONNECTOR="$CONNECTOR"
  CLIENTCMD="steam -gamepadui -pipewire-dmabuf"
  GAMESCOPECMD="/usr/bin/gamescope --hdr-enabled --hdr-itm-enable --hide-cursor-delay 3000 --fade-out-duration 200 -W \$SCREEN_WIDTH -H \$SCREEN_HEIGHT -O \$CONNECTOR"
fi
EOF

  echo -e "\033[1;32mГотово!\033[0m Запустите Steam в Big Picture режиме"
}

# === Вспомогательные функции ===
function check_root_permissions() {
  [[ $EUID -ne 0 ]] && { log "Требуются root-права!"; exit 1; }
}

function check_file_exists() {
  [ ! -f "$1" ] && { log "Файл $1 не найден!"; exit 1; }
}

function backup_file() {
  local backup="${1}.bak_$(date +%s)"
  cp "$1" "$backup" && log "Резервная копия: $backup"
}

function enable_debug() {
  DEBUG=true
  set -x
}

# === Интерфейс ===
function print_menu() {
  clear
  echo -e "\033[1;44m========[ Vulkan/HDR Configuration ]========\033[0m"
  echo -e "\033[1;34m 1. Установить переменные (пользователь)\033[0m"
  echo -e "\033[1;34m 2. Установить переменные (система)\033[0m"
  echo -e "\033[1;36m 3. Проверить текущие настройки\033[0m"
  echo -e "\033[1;31m 4. Отменить изменения\033[0m"
  echo -e "\033[1;35m 5. Проверить поддержку HDR\033[0m"
  echo -e "\033[1;35m 6. Настроить HDR для Steam\033[0m"
  echo -e "\033[1;33m 7. Показать лог\033[0m"
  echo -e "\033[1;37m 0. Выход\033[0m"
  echo -e "\033[1;44m============================================\033[0m"
}

# === Главный цикл ===
function main() {
  init_script
  while true; do
    print_menu
    read -p "Выберите действие: " choice
    case $choice in
      1) setup_for_user ;;
      2) setup_for_all_users ;;
      3) check_current_vars ;;
      4) undo_changes ;;
      5) check_hdr_support ;;
      6) setup_steam_hdr ;;
      7) less "$LOG_FILE" ;;
      0) exit 0 ;;
      *) echo "Неверный выбор!" ;;
    esac
    read -p "Нажмите Enter чтобы продолжить..."
  done
}

# === Запуск ===
[[ "$1" == "--debug" ]] && enable_debug
main
