#!/bin/bash
#
# Скрипт для ALT Linux (и не только),
# который прописывает переменные окружения Vulkan:
#   AMD_VULKAN_FSR=1
#   RADV_PERFTEST=aco
#   RADV_DEBUG=zerovram
#
# Возможности:
#   1) Установить переменные только для текущего пользователя (в ~/.bashrc)
#   2) Установить переменные для всех пользователей (в /etc/environment)

# === Настраиваемые значения переменных ===
VARS=(
  "AMD_VULKAN_FSR=1"
  "RADV_PERFTEST=aco,gpl,ngg"
  "RADV_DEBUG=zerovram"
)

# === Функция для добавления в ~/.bashrc ===
function setup_for_user() {
  local BASHRC_FILE="$HOME/.bashrc"

  echo ">>> Добавляем переменные в $BASHRC_FILE"

  # Создадим резервную копию, если захотим откатить
  cp "$BASHRC_FILE" "$BASHRC_FILE.bak_$(date +%Y%m%d%H%M%S)"

  # Пропишем строки в конец .bashrc (если их там ещё нет)
  for var in "${VARS[@]}"; do
    # Проверим, нет ли уже такой строки
    if ! grep -q "^export $var" "$BASHRC_FILE" 2>/dev/null; then
      echo "export $var" >> "$BASHRC_FILE"
      echo "  Добавлено: export $var"
    else
      echo "  Переменная уже есть: export $var"
    fi
  done

  echo ">>> Изменения внесены. Чтобы применить их сразу в текущей сессии, выполните:"
  echo "source $BASHRC_FILE"
}

# === Функция для добавления в /etc/environment ===
function setup_for_all_users() {
  local ENV_FILE="/etc/environment"

  # Проверим, запущен ли скрипт с правами root
  if [[ $EUID -ne 0 ]]; then
    echo "Ошибка: для записи в /etc/environment нужны права root."
    echo "Перезапустите скрипт с sudo или под root."
    exit 1
  fi

  echo ">>> Добавляем переменные в $ENV_FILE"

  # Создадим резервную копию
  cp "$ENV_FILE" "$ENV_FILE.bak_$(date +%Y%m%d%H%M%S)"

  # Для /etc/environment формат строк — без "export"
  for var in "${VARS[@]}"; do
    # var выглядит как "AMD_VULKAN_FSR=1"
    local KEY="${var%=*}"
    local VAL="${var#*=}"

    # Проверим, нет ли уже такой строки (или переменной)
    if ! grep -q "^$KEY=" "$ENV_FILE" 2>/dev/null; then
      echo "$var" >> "$ENV_FILE"
      echo "  Добавлено: $var"
    else
      echo "  Переменная уже существует: $KEY (проверьте $ENV_FILE вручную, если нужно изменить)"
    fi
  done

  echo ">>> Изменения внесены. Для активации лучше всего перезагрузить систему."
}

# === Главное меню ===
echo "=============================================="
echo " Скрипт настройки Vulkan-переменных в ALT Linux"
echo "=============================================="
echo " 1) Установить переменные только для текущего пользователя (~/.bashrc)"
echo " 2) Установить переменные для всех пользователей (/etc/environment)"
echo " q) Выход"
echo "----------------------------------------------"
read -p "Выберите пункт меню: " choice

case "$choice" in
  1)
    setup_for_user
    ;;
  2)
    setup_for_all_users
    ;;
  q|Q)
    echo "Выход..."
    ;;
  *)
    echo "Неверный выбор"
    ;;
esac

exit 0
