#!/bin/bash
#
# Скрипт для настройки переменных окружения Vulkan в Ubuntu (и других дистрибутивах Linux)
#
# Устанавливает следующие переменные:
#   AMD_VULKAN_FSR=1
#   RADV_PERFTEST=aco,gpl,ngg
#   RADV_DEBUG=zerovram
#
# Возможности:
#   1) Добавить переменные только для текущего пользователя (в ~/.bashrc)
#   2) Добавить переменные для всех пользователей (в /etc/environment)

# === Настраиваемые значения переменных ===
VARS=(
  "AMD_VULKAN_FSR=1"
  "RADV_PERFTEST=aco,gpl,ngg"
  "RADV_DEBUG=zerovram"
)

# === Функция для добавления в ~/.bashrc (только для текущего пользователя) ===
setup_for_user() {
  local BASHRC_FILE="$HOME/.bashrc"

  echo ">>> Добавляем переменные в $BASHRC_FILE"

  # Если файл не существует, создаем его
  if [ ! -f "$BASHRC_FILE" ]; then
    touch "$BASHRC_FILE"
    echo "Файл $BASHRC_FILE не найден. Создан новый."
  fi

  # Создаем резервную копию для отката изменений
  cp "$BASHRC_FILE" "$BASHRC_FILE.bak_$(date +%Y%m%d%H%M%S)"

  # Добавляем строки в конец ~/.bashrc (если их там ещё нет)
  for var in "${VARS[@]}"; do
    if ! grep -q "^export $var" "$BASHRC_FILE" 2>/dev/null; then
      echo "export $var" >> "$BASHRC_FILE"
      echo "  Добавлено: export $var"
    else
      echo "  Переменная уже есть: export $var"
    fi
  done

  echo ">>> Изменения внесены. Чтобы применить их сразу, выполните:"
  echo "source $BASHRC_FILE"
}

# === Функция для добавления в /etc/environment (для всех пользователей) ===
setup_for_all_users() {
  local ENV_FILE="/etc/environment"

  # Проверяем, запущен ли скрипт с правами root
  if [[ $EUID -ne 0 ]]; then
    echo "Ошибка: для изменения $ENV_FILE требуются права суперпользователя."
    echo "Запустите скрипт с sudo или под root."
    exit 1
  fi

  echo ">>> Добавляем переменные в $ENV_FILE"

  # Создаем резервную копию файла /etc/environment
  cp "$ENV_FILE" "$ENV_FILE.bak_$(date +%Y%m%d%H%M%S)"

  # Для /etc/environment переменные записываются без 'export'
  for var in "${VARS[@]}"; do
    local KEY="${var%%=*}"
    if ! grep -q "^$KEY=" "$ENV_FILE" 2>/dev/null; then
      echo "$var" >> "$ENV_FILE"
      echo "  Добавлено: $var"
    else
      echo "  Переменная уже существует: $KEY. Проверьте $ENV_FILE, если хотите изменить значение."
    fi
  done

  echo ">>> Изменения внесены. Рекомендуется перезагрузить систему для их активации."
}

# === Главное меню ===
echo "=============================================="
echo " Скрипт настройки Vulkan-переменных в Ubuntu"
echo "=============================================="
echo " 1) Установить переменные для текущего пользователя (~/.bashrc)"
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
