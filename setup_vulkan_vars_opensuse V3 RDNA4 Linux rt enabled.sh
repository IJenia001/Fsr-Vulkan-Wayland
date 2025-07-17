#!/bin/bash
#
# Vulkan Ray Tracing Enabler for AMD RDNA 4
# OpenSUSE Tumbleweed
#

# === Настройки трассировки лучей ===
VARS=(
  # Core Ray Tracing
  "RADV_PERFTEST=rt,rt_skip_invariant,bindless_rt,wave64"
  "RADV_DEBUG=nocache,zerovram"
  
  # API Support
  "VK_ENABLE_BETA_EXTENSIONS=1"
  "VK_KHR_ray_tracing_pipeline=1"
  "VK_KHR_acceleration_structure=1"

  "DXVK_HDR=1" # Включить HDR в DXVK
  
  # Game/Proton Support
  "DXVK_RAYTRACING=1"
  "VKD3D_CONFIG=rt,dxr11"
  "PROTON_ENABLE_NVAPI=1"
  
  # RDNA 4 Optimizations
  "RADV_TUNING=rdna4"
  "RADV_VIDEO_DECODE=av1"
  
  # Experimental Features
  "RADV_DEBUG=inline_ray_tracing"
  "AMD_DEBUG=rtvm"
)

# === Проверка поддержки RT ===
check_rt_support() {
    echo "Проверка поддержки трассировки лучей:"
    
    # Проверка оборудования
    local gpu_cap
    gpu_cap=$(lspci -nn | grep -i "VGA\|3D" | grep -i "AMD/ATI")
    if [[ ! "$gpu_cap" =~ "RDNA 4" ]]; then
        echo "⚠️  Ваша карта: ${gpu_cap:-Не обнаружена}"
        echo "   Требуется RDNA 2/3/4 для аппаратного RT"
    fi
    
    # Проверка драйвера
    local mesa_ver
    mesa_ver=$(rpm -q --queryformat '%{VERSION}' mesa 2>/dev/null | cut -d. -f1-2)
    if [[ -z "$mesa_ver" ]] || [[ $(echo "$mesa_ver < 23.3" | bc -l) -eq 1 ]]; then
        echo "❌ Требуется Mesa 23.3+ (установлено: ${mesa_ver:-Не найдено})"
        echo "   Обновите: sudo zypper dup"
        return 1
    fi
    
    # Проверка расширений Vulkan
    if vulkaninfo | grep -q "VK_KHR_ray_tracing_pipeline"; then
        echo "✅ Поддержка RT обнаружена в драйвере"
    else
        echo "❌ Расширения RT не найдены!"
        return 1
    fi
    
    echo "------------------------------------------"
    return 0
}

# === Функция установки ===
setup_raytracing() {
    local target_file="$1"
    local is_system="$2"
    local prefix=""
    
    [ "$is_system" = "1" ] && prefix="sudo "
    
    echo -e "\n⚙️  Настройка трассировки лучей в: $target_file"
    
    # Создание резервной копии
    $prefix cp -v "$target_file" "${target_file}.bak_rt_$(date +%s)"
    
    # Добавляем раздел
    $prefix bash -c "echo -e '\n# Ray Tracing Settings (RDNA 4)' >> \"$target_file\""
    
    # Добавляем переменные
    for var in "${VARS[@]}"; do
        if [ "$is_system" = "1" ]; then
            # Для /etc/environment
            if ! $prefix grep -q "^${var%%=*}" "$target_file"; then
                $prefix bash -c "echo '$var' >> \"$target_file\""
                echo "  ➕ $var"
            fi
        else
            # Для ~/.profile
            if ! grep -q "^export $var" "$target_file" 2>/dev/null; then
                echo "export $var" | $prefix tee -a "$target_file" >/dev/null
                echo "  ➕ export $var"
            fi
        fi
    done
    
    echo -e "\n✨ Настройки RT применены!"
}

# === Главное меню ===
echo "========================================"
echo " Включение трассировки лучей для RDNA 4"
echo "========================================"

# Проверка поддержки
if ! check_rt_support; then
    echo -e "\n❌ Система не готова для трассировки лучей!"
    exit 1
fi

echo -e "\nВыберите метод установки:"
echo " 1) Текущий пользователь (~/.profile)"
echo " 2) Все пользователи (/etc/environment)"
echo " 3) Только для сессии (временная)"
echo -e " q) Выход\n"

read -p "Ваш выбор: " choice

case "$choice" in
    1)
        setup_raytracing "$HOME/.profile" 0
        echo -e "\n🔁 Перезайдите в систему или выполните:"
        echo "source ~/.profile"
        ;;
    2)
        setup_raytracing "/etc/environment" 1
        echo -e "\n🔄 Требуется перезагрузка системы!"
        ;;
    3)
        echo -e "\n💨 Временные переменные для текущей сессии:"
        for var in "${VARS[@]}"; do
            echo "export $var"
            export "$var"
        done
        echo -e "\nПеременные установлены до завершения сессии терминала."
        ;;
    q|Q)
        exit 0
        ;;
    *)
        echo "Неверный выбор"
        ;;
esac

# Проверка активации
echo -e "\nПроверить настройки:"
echo "vulkaninfo | grep -i ray"
echo "или запустите игру с поддержкой RT"
