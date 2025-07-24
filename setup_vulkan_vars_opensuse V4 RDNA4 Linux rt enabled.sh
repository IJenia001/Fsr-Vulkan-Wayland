#!/bin/bash
#
# Vulkan Environment Optimizer for AMD RDNA 4
# OpenSUSE Tumbleweed Edition
# Includes Ray Tracing, FSR and ACO optimizations
#

# Проверка архитектуры GPU
check_gpu_architecture() {
    local gpu_info
    gpu_info=$(lspci -nn | grep -i "VGA\|3D" | grep -i "AMD/ATI")
    
    if [[ -z "$gpu_info" ]]; then
        echo "⚠️  Предупреждение: AMD GPU не обнаружена!"
        read -p "Продолжить установку? (y/N): " confirm
        [[ "$confirm" != "y" ]] && exit 1
        return
    fi
    
    if [[ ! "$gpu_info" =~ "RDNA 4" ]]; then
        echo "⚠️  Внимание: Скрипт оптимизирован для RDNA 4!"
        echo "Обнаружен GPU: $gpu_info"
        read -p "Продолжить установку? (y/N): " confirm
        [[ "$confirm" != "y" ]] && exit 1
    fi
}

# === Оптимизированные переменные для RDNA 4 ===
VARS=(
  # Основные оптимизации
  "RADV_PERFTEST=aco,rt,ngg,bindless_rt,wave32"
  "RADV_DEBUG=nofallback"

  # Оптимизации трассировки лучей
  "RADV_BINDLESS_RAYTRACING=1"
  "RADV_RAY_QUERY=1"

  # Технологии повышения качества изображения
  "RADV_IMAGE_SS=1"  # Super Sampling (FSR альтернатива)

  # Специфичные настройки RDNA 4
  "RADV_TUNING=rdna4"
  "RADV_VIDEO_DECODE=av1,vp9,hevc"

  # Оптимизации памяти
  "RADV_ZERO_VRAM=1"

  # Экспериментальные функции
  "RADV_ENABLE_MESH_SHADERS=1"
  "RADV_USE_LLVM=0"  # Принудительное использование ACO
)

# === Установка для текущего пользователя (~/.profile) ===
setup_for_user() {
    local PROFILE_FILE="$HOME/.profile"
    local backup_file="$PROFILE_FILE.bak_$(date +%Y%m%d%H%M%S)"
    
    echo -e "\n🔧 Установка для текущего пользователя: $USER"
    
    # Создаем файл если не существует
    [[ ! -f "$PROFILE_FILE" ]] && touch "$PROFILE_FILE"
    
    # Создаем резервную копию
    cp -v "$PROFILE_FILE" "$backup_file"
    
    # Добавляем заголовок раздела
    echo -e "\n# Vulkan Optimizations for RDNA 4 (added $(date +%Y-%m-%d))" >> "$PROFILE_FILE"
    
    local added_count=0
    for var in "${VARS[@]}"; do
        # Удаляем существующую переменную
        sed -i "/export ${var%%=*}=/d" "$PROFILE_FILE"
        
        # Добавляем новое значение
        echo "export $var" >> "$PROFILE_FILE"
        echo "   ✅ Установлено: $var"
        ((added_count++))
    done
    
    if [[ $added_count -gt 0 ]]; then
        echo -e "\n✨ Успешно добавлено $added_count переменных!"
        echo -e "Для применения изменений выполните:\n"
        echo -e "   source \"$PROFILE_FILE\""
        echo -e "   или перезайдите в систему\n"
    else
        echo -e "\nℹ️  Все переменные уже настроены. Изменения не требуются."
    fi
    
    echo "🔁 Резервная копия создана: $backup_file"
}

# === Установка для всех пользователей (/etc/environment) ===
setup_for_all_users() {
    local ENV_FILE="/etc/environment"
    local backup_file="$ENV_FILE.bak_$(date +%Y%m%d%H%M%S)"
    
    # Проверка прав root
    if [[ $EUID -ne 0 ]]; then
        echo -e "\n❌ Ошибка: Требуются права root!"
        echo "Запустите скрипт с помощью sudo:"
        echo -e "   sudo $0\n"
        exit 1
    fi
    
    echo -e "\n🌍 Установка для всех пользователей системы"
    
    # Создаем резервную копию
    cp -v "$ENV_FILE" "$backup_file"
    
    # Добавляем заголовок раздела
    echo -e "\n# Vulkan Optimizations for RDNA 4 (added $(date +%Y-%m-%d))" >> "$ENV_FILE"
    
    local added_count=0
    for var in "${VARS[@]}"; do
        local key="${var%%=*}"
        # Удаляем существующую переменную
        sed -i "/^$key=/d" "$ENV_FILE"
        
        # Добавляем новое значение
        echo "$var" >> "$ENV_FILE"
        echo "   ✅ Установлено: $var"
        ((added_count++))
    done
    
    if [[ $added_count -gt 0 ]]; then
        echo -e "\n✨ Успешно добавлено $added_count переменных!"
        echo -e "Требуется перезагрузка системы для применения изменений:\n"
        echo -e "   sudo reboot\n"
    else
        echo -e "\nℹ️  Все переменные уже настроены. Изменения не требуются."
    fi
    
    echo "🔁 Резервная копия создана: $backup_file"
}

# === Проверка системы ===
check_system() {
    echo -e "Проверка системы:\n"
    
    # Проверка дистрибутива
    if ! grep -qi "opensuse tumbleweed" /etc/os-release; then
        echo "⚠️  Предупреждение: Скрипт предназначен для OpenSUSE Tumbleweed"
        read -p "Продолжить установку? (y/N): " confirm
        [[ "$confirm" != "y" ]] && exit 1
    fi
    
    # Проверка версии Mesa
    local mesa_version=$(rpm -q --queryformat '%{VERSION}' mesa 2>/dev/null | cut -d. -f1-2)
    if [[ -z "$mesa_version" ]]; then
        echo "❌ Ошибка: Пакет Mesa не установлен!"
        echo "Установите: sudo zypper install Mesa"
        exit 1
    elif [[ $(echo "$mesa_version < 24.1" | bc -l) -eq 1 ]]; then
        echo "⚠️  Требуется обновление Mesa (текущая: $mesa_version, требуется: 24.1+)"
        echo "Обновите: sudo zypper dup"
    fi
    
    # Проверка поддержки Vulkan
    if ! command -v vulkaninfo &> /dev/null; then
        echo "❌ Vulkan Tools не установлены!"
        echo "Установите: sudo zypper install vulkan-tools"
        exit 1
    fi
    
    echo -e "------------------------------------------"
}

# === Главное меню ===
show_menu() {
    clear
    echo -e "\n=============================================="
    echo " Vulkan Optimizer for AMD RDNA 4"
    echo " OpenSUSE Tumbleweed Edition"
    echo "=============================================="
    echo -e " Текущая система: $(grep PRETTY_NAME /etc/os-release | cut -d= -f2 | tr -d '\"')"
    echo -e " Текущий пользователь: $USER\n"
    
    check_gpu_architecture
    
    echo -e "\nВыберите действие:\n"
    echo " 1) Установить для текущего пользователя (~/.profile)"
    echo " 2) Установить для всех пользователей (/etc/environment)"
    echo " 3) Проверить текущие настройки Vulkan"
    echo " 4) Удалить настройки (из ~/.profile)"
    echo " q) Выход"
    echo -e "\n----------------------------------------------"
    
    read -p "Ваш выбор: " choice
}

# === Проверка текущих настроек ===
check_current_settings() {
    echo -e "\n🔍 Текущие настройки Vulkan:\n"
    
    # Проверка переменных окружения
    echo "Переменные окружения:"
    for var in "${VARS[@]}"; do
        local key="${var%%=*}"
        echo -n "   $key: "
        if grep -q "^export $key=" ~/.profile 2>/dev/null; then
            echo -n "[пользователь] "
        fi
        if grep -q "^$key=" /etc/environment 2>/dev/null; then
            echo -n "[система] "
        fi
        env | grep "^$key=" || echo "не установлено"
    done
    
    # Информация о драйвере
    echo -e "\nИнформация о драйвере:"
    vulkaninfo | grep -E "driverName|driverInfo|apiVersion" | head -3
    
    # Проверка ключевых функций
    echo -e "\nПроверка функций RDNA 4:"
    vulkaninfo | grep -E \
      "VK_KHR_ray_tracing_pipeline|VK_KHR_shader_float_controls|RADV_PERFTEST|RADV_BINDLESS_RAYTRACING"
    
    echo
}

# === Удаление настроек ===
remove_settings() {
    local PROFILE_FILE="$HOME/.profile"
    local backup_file="$PROFILE_FILE.clean_$(date +%Y%m%d%H%M%S)"
    
    [[ ! -f "$PROFILE_FILE" ]] && return
    
    cp -v "$PROFILE_FILE" "$backup_file"
    
    # Удаляем раздел с настройками
    sed -i '/# Vulkan Optimizations for RDNA 4/,/^$/d' "$PROFILE_FILE"
    
    # Удаляем все переменные из VARS
    for var in "${VARS[@]}"; do
        local key="${var%%=*}"
        sed -i "/^export $key=/d" "$PROFILE_FILE"
    done
    
    echo -e "\nНастройки удалены из ~/.profile"
    echo "Резервная копия сохранена: $backup_file"
}

# === Главная функция ===
main() {
    check_system
    
    while true; do
        show_menu
        
        case "$choice" in
            1)
                setup_for_user
                ;;
            2)
                setup_for_all_users
                ;;
            3)
                check_current_settings
                ;;
            4)
                remove_settings
                ;;
            q|Q)
                echo -e "\nВыход...\n"
                exit 0
                ;;
            *)
                echo "Неверный выбор"
                ;;
        esac
        
        read -p "Нажмите Enter для продолжения..."
    done
}

# Запуск
main