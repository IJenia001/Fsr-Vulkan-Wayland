Описание для V4

🔧 # Основные оптимизации (полный набор wave32)
✅ RADV_PERFTEST=aco,rt,ngg,bindless_rt,wave32,rtwave32,pswave32,cswave32,gewave32,rt_prim_culling
aco — использование компилятора шейдеров ACO, более быстрый и эффективный, чем LLVM.

rt — включает трассировку лучей.

ngg — Next-Gen Geometry, ускоряет обработку геометрии (тесселяция, culling).

bindless_rt — активирует bindless ray tracing, для доступа к данным без биндинга.

wave32 — использовать 32-поточные волны (вместо стандартных 64-поточных), уменьшает латентность.

rtwave32, pswave32, cswave32, gewave32 — активируют wave32 для конкретных шейдеров:

rtwave32 — для трассировки лучей,

pswave32 — pixel shader,

cswave32 — compute shader,

gewave32 — geometry/VS.

rt_prim_culling — включает предварительное отсечение геометрии до трассировки лучей.

✅ RADV_DEBUG=nofallback,novrsfl,noinfinitecache
nofallback — отключает переход на «медленные» fallback-режимы.

novrsfl — не использовать fallback для VRS (Variable Rate Shading).

noinfinitecache — отключает агрессивное кэширование, которое может занимать много памяти и замедлять.

🚀 # Расширенные функции GFX12
✅ RADV_GFX12_OPTIONS=dual_rt_engines,compact_bvh
dual_rt_engines — использовать оба движка трассировки лучей на RDNA4 для параллельного RT.

compact_bvh — включает оптимизированную структуру BVH (Bounding Volume Hierarchy), снижает потребление VRAM.

✅ RADV_ENABLE_64B_VKRT_NODES=1
Использовать 64-битные узлы в трассировке лучей для повышения точности и совместимости.

🔦 # Оптимизации трассировки лучей
✅ RADV_BINDLESS_RAYTRACING=1
Позволяет доступ к ресурсам в RT без заранее установленных дескрипторов — быстрее, гибче.

✅ RADV_RAY_QUERY=1
Включает поддержку rayQuery (инлайн трассировка внутри compute/pixel шейдеров, без вызова rayGen).

✅ RADV_RT_MAX_LEVEL=2
Задает уровень вложенности BVH для трассировки. 2 — безопасное значение для игр/рендеров.

🎥 # Видео и медиа
✅ RADV_VIDEO_DECODE=av1,vp9,hevc,avc
Включает поддержку аппаратного декодирования видео:

av1, vp9 — современные web-форматы,

hevc — H.265,

avc — H.264.

✅ RADV_VIDEO_ENCODE=av1
Включает поддержку аппаратной кодировки AV1 (если поддерживается RDNA4 и Mesa).

💾 # Память и производительность
✅ RADV_ZERO_VRAM=1
Обнулять содержимое VRAM при выделении (безопасность, но может снизить производительность).

✅ RADV_DCC=2
Delta Color Compression:

2 — принудительно включить DCC (улучшает эффективность работы с текстурами и буферами).

✅ RADV_OPTIMIZE_VRAM_BANDWIDTH=1
Включает оптимизации, уменьшающие потребление пропускной способности видеопамяти.

✅ RADV_RESIZABLE_BAR=1
Включает Resizable BAR, чтобы CPU мог напрямую обращаться ко всей видеопамяти — ускоряет загрузку ресурсов и стриминг.

🧪 # Экспериментальные функции
✅ RADV_ENABLE_MESH_SHADERS=1
Включает поддержку Mesh Shaders (более гибкие, GPU-дружественные шейдеры геометрии, требуется поддержка в Vulkan и приложении).

✅ RADV_ENABLE_TASK_SHADERS=1
Включает Task Shaders, предварительный этап перед Mesh, для распределения задач.

✅ RADV_USE_LLVM=0
Отключает использование LLVM для компиляции, используется только ACO (быстрее, но может не поддерживать всё).

✅ RADV_GFX12_ENABLE_OBB=1
Включает Optimized Bounding Boxes (новая фича в RDNA4 для RT и Culling).

✅ RADV_MAX_LIGHTS=256
Устанавливает лимит максимального количества источников света, которые может обрабатывать GPU одновременно. Полезно для движков с кастомным освещением.

⚠️ Примечания:
Некоторые переменные являются экспериментальными и могут работать нестабильно в зависимости от версии Mesa, ядра и прошивки GPU.

Все эти опции имеют смысл только если используется RADV (Mesa Vulkan), не работают для AMDVLK или проприетарного драйвера.
