#!/bin/bash
#
# Скрипт для настройки переменных окружения Vulkan в OpenSUSE Tumbleweed
#
# Устанавливает следующие переменные:
#   AMD_VULKAN_FSR=1
#   RADV_PERFTEST=aco,gpl,ngg
#   RADV_DEBUG=zerovram
#
# Возможности:
#   1) Добавить переменные только для текущего пользователя (в ~/.profile)
#   2) Добавить переменные для всех пользователей (в /etc/environment)

# === Настраиваемые значения переменных ===
VARS=(
  "AMD_VULKAN_FSR=1"
  "RADV_PERFTEST=dccmsaa,gpl,nggc,nv_ms,rt,rtwave64,sam"
  "RADV_DEBUG=zerovram"
  "DXVK_HDR=1"
  "VK_EXT_HDR_METADATA=1"
)

# === Функция для добавления в ~/.profile (только для текущего пользователя) ===
setup_for_user() {
  local PROFILE_FILE="$HOME/.profile"

  echo ">>> Добавляем переменные в $PROFILE_FILE"

  # Если файл не существует, создаем его
  if [ ! -f "$PROFILE_FILE" ]; then
    touch "$PROFILE_FILE"
    echo "Файл $PROFILE_FILE не найден. Создан новый."
  fi

  # Создаем резервную копию
  cp "$PROFILE_FILE" "$PROFILE_FILE.bak_$(date +%Y%m%d%H%M%S)"

  # Добавляем строки в конец ~/.profile (если их там ещё нет)
  for var in "${VARS[@]}"; do
    if ! grep -q "^export $var" "$PROFILE_FILE" 2>/dev/null; then
      echo "export $var" >> "$PROFILE_FILE"
      echo "  Добавлено: export $var"
    else
      echo "  Переменная уже есть: export $var"
    fi
  done

  echo ">>> Изменения внесены. Для применения:"
  echo "1. Закройте текущий терминал"
  echo "2. Выйдите из системы и войдите заново"
  echo "ИЛИ выполните: source $PROFILE_FILE (для текущей сессии терминала)"
}

# === Функция для добавления в /etc/environment (для всех пользователей) ===
setup_for_all_users() {
  local ENV_FILE="/etc/environment"

  # Проверка прав root
  if [[ $EUID -ne 0 ]]; then
    echo "Ошибка: для изменения $ENV_FILE требуются права суперпользователя."
    echo "Запустите скрипт с sudo: sudo $0"
    exit 1
  fi

  echo ">>> Добавляем переменные в $ENV_FILE"

  # Создаем резервную копию
  cp "$ENV_FILE" "$ENV_FILE.bak_$(date +%Y%m%d%H%M%S)"

  # Для /etc/environment используем синтаксис без export
  for var in "${VARS[@]}"; do
    local KEY="${var%%=*}"
    if ! grep -q "^$KEY=" "$ENV_FILE" 2>/dev/null; then
      # Добавляем в конец файла
      echo "$var" >> "$ENV_FILE"
      echo "  Добавлено: $var"
    else
      echo "  Переменная уже существует: $KEY. Значение не изменено."
      echo "  Вручную проверьте $ENV_FILE при необходимости."
    fi
  done

  echo ">>> Изменения внесены. Требуется ПЕРЕЗАГРУЗКА СИСТЕМЫ для применения."
}

# === Главное меню ===
echo "=============================================="
echo " Скрипт настройки Vulkan-переменных в OpenSUSE"
echo "=============================================="
echo " 1) Установить для текущего пользователя (~/.profile)"
echo " 2) Установить для всех пользователей (/etc/environment)"
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