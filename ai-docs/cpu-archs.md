# CPU Architectures and Features Supported by llama.cpp

This document provides a comprehensive analysis of the CPU architectures and features supported by the llama.cpp project based on a thorough examination of the codebase.

## 1. x86/x86_64 Architecture

### SSE Instruction Sets
The code supports various x86 SSE instruction sets, with optimizations for different generations.

**References:**
- `ggml-cpu/cpu-feats-x86.cpp`: Contains SSE detection code
  ```c
  bool SSE3(void) { return f_1_ecx[0]; }
  bool SSSE3(void) { return f_1_ecx[9]; }
  bool SSE41(void) { return f_1_ecx[19]; }
  bool SSE42(void) { return f_1_ecx[20]; }
  ```

- `CMakeLists.txt`: Contains SSE4.2 build option
  ```cmake
  #ifdef GGML_SSE42
  if (!is.SSE42()) { return 0; }
  score += 1<<2;
  #endif
  ```

### AVX, AVX2, and FMA Instruction Sets
The code supports various x86 SIMD instruction sets, with specific optimizations for AVX, AVX2, and FMA.

**References:**
- `ggml.c`: Contains extensive AVX/AVX2/FMA optimized implementations
  ```c
  #if defined(__AVX__) || defined(__AVX2__) || defined(__AVX512F__)
  // AVX-optimized implementations
  #endif
  ```

- `CMakeLists.txt`: Compiler flags for enabling AVX instructions
  ```cmake
  option(GGML_AVX           "ggml: enable AVX"              ${INS_ENB})
  option(GGML_AVX2          "ggml: enable AVX2"             ${INS_ENB})
  if (NOT MSVC)
      option(GGML_FMA       "ggml: enable FMA"              ${INS_ENB})
  endif()
  ```

### AVX-512 Instruction Set
Advanced vector extensions with 512-bit support, with multiple variant support.

**References:**
- `ggml-cpu/cpu-feats-x86.cpp`: Contains detailed AVX-512 variant detection
  ```c
  bool AVX512F(void) { return f_7_ebx[16]; }
  bool AVX512DQ(void) { return f_7_ebx[17]; }
  bool AVX512BW(void) { return f_7_ebx[30]; }
  bool AVX512VL(void) { return f_7_ebx[31]; }
  bool AVX512CD(void) { return f_7_ebx[28]; }
  ```

- `CMakeLists.txt`: Configuration for AVX-512 variants
  ```cmake
  option(GGML_AVX512          "ggml: enable AVX512F"          OFF)
  option(GGML_AVX512_VBMI     "ggml: enable AVX512-VBMI"      OFF)
  option(GGML_AVX512_VNNI     "ggml: enable AVX512-VNNI"      OFF)
  option(GGML_AVX512_BF16     "ggml: enable AVX512-BF16"      OFF)
  ```

- `ggml-cpu.cpp`: Checks for AVX-512 variants at runtime
  ```c
  if (ggml_cpu_has_avx512()) {
      features.push_back({ "AVX512", "1" });
  }
  if (ggml_cpu_has_avx512_vbmi()) {
      features.push_back({ "AVX512_VBMI", "1" });
  }
  if (ggml_cpu_has_avx512_vnni()) {
      features.push_back({ "AVX512_VNNI", "1" });
  }
  if (ggml_cpu_has_avx512_bf16()) {
      features.push_back({ "AVX512_BF16", "1" });
  }
  ```

### AVX-VNNI Instructions
Intel's AVX Vector Neural Network Instructions, introduced in Alder Lake processors.

**References:**
- `ggml-cpu/cpu-feats-x86.cpp`: Has detection code
  ```c
  bool AVX_VNNI(void) { return f_7_1_eax[4]; }
  ```

- `CMakeLists.txt`: Build option
  ```cmake
  option(GGML_AVX_VNNI        "ggml: enable AVX-VNNI"         OFF)
  ```

### F16C Instructions
Half-precision floating-point conversion instructions.

**References:**
- `CMakeLists.txt`: Enabled with AVX2
  ```cmake
  if (NOT MSVC)
      option(GGML_F16C     "ggml: enable F16C"             ${INS_ENB})
  endif()
  ```

### AMX Instructions
Advanced Matrix Extensions for accelerating matrix operations, primarily used for AI workloads.

**References:**
- `ggml-cpu/cpu-feats-x86.cpp`: Contains detection for AMX variants
  ```c
  bool AMX_TILE(void) { return f_7_edx[24]; }
  bool AMX_INT8(void) { return f_7_edx[25]; }
  bool AMX_FP16(void) { return f_7_1_eax[21]; }
  bool AMX_BF16(void) { return f_7_edx[22]; }
  ```

- `CMakeLists.txt`: Build options for AMX variants
  ```cmake
  if (NOT MSVC)
      option(GGML_AMX_TILE     "ggml: enable AMX-TILE"         OFF)
      option(GGML_AMX_INT8     "ggml: enable AMX-INT8"         OFF)
      option(GGML_AMX_BF16     "ggml: enable AMX-BF16"         OFF)
  endif()
  ```

- Dedicated AMX implementation in `ggml/src/ggml-cpu/amx/` directory

## 2. ARM Architecture

### NEON SIMD Extensions
ARM's SIMD technology for mobile and embedded processors.

**References:**
- `ggml.c`: Contains ARM NEON implementations
  ```c
  #if defined(__ARM_NEON)
  // NEON-optimized implementations
  #endif
  ```

### ARM SVE (Scalable Vector Extension)
Used in newer ARM architectures.

**References:**
- `ggml.c`: Contains ARM SVE optimized paths
  ```c
  #if defined(__ARM_FEATURE_SVE)
  // SVE-optimized implementations
  #endif
  ```

### ARM SME (Scalable Matrix Extension)
Extension to SVE that adds matrix multiplication capabilities.

**References:**
- `ggml-cpu.h`: Function to check for SME support
  ```c
  GGML_BACKEND_API int ggml_cpu_has_sme(void);
  ```

### Apple Silicon Optimizations
Specific optimizations for Apple's M-series chips.

**References:**
- `ggml.c`: Contains specific Apple Silicon optimizations
  ```c
  #if defined(__APPLE__) && defined(__aarch64__)
  // Apple Silicon specific optimizations
  #endif
  ```

## 3. RISC-V Architecture

### RVV (RISC-V Vector Extension)
SIMD instructions for RISC-V processors.

**References:**
- `ggml-cpu.h`: Function to check for RISC-V Vector support
  ```c
  GGML_BACKEND_API int ggml_cpu_has_riscv_v(void);
  ```

- `CMakeLists.txt`: Build option
  ```cmake
  option(GGML_RVV           "ggml: enable rvv"              ON)
  ```

## 4. LOONGARCH Architecture

### LSX/LASX (LOONGARCH SIMD Extensions)
SIMD instructions for LOONGARCH processors.

**References:**
- `ggml-cpu.h`: Function to check for VSX support
  ```c
  GGML_BACKEND_API int ggml_cpu_has_vsx(void);
  ```

- `CMakeLists.txt`: Build options
  ```cmake
  option(GGML_LASX         "ggml: enable lasx"             ON)
  option(GGML_LSX          "ggml: enable lsx"              ON)
  ```

## 5. S390x Architecture

### VXE (Vector Extension)
SIMD instructions for S390x processors.

**References:**
- `ggml-cpu.h`: Function to check for VXE support
  ```c
  GGML_BACKEND_API int ggml_cpu_has_vxe(void);
  ```

- `CMakeLists.txt`: Build option
  ```cmake
  option(GGML_VXE          "ggml: enable vxe"              ON)
  ```

## 6. WASM/SIMD Support

**References:**
- `CMakeLists.txt`: WASM SIMD configuration
  ```cmake
  if(LLAMA_WASM_SIMD)
    add_compile_options(-msimd128)
  endif()
  ```

## 7. Generic CPU Features

### BLAS Integration
Support for Basic Linear Algebra Subprograms libraries.

**References:**
- `CMakeLists.txt`:
  ```cmake
  option(GGML_BLAS                       "ggml: use BLAS"                                  ${GGML_BLAS_DEFAULT})
  set(GGML_BLAS_VENDOR ${GGML_BLAS_VENDOR_DEFAULT} CACHE STRING
                                            "ggml: BLAS library vendor")
  ```

### OpenMP Support
Multi-threading support through OpenMP.

**References:**
- `CMakeLists.txt`:
  ```cmake
  option(GGML_OPENMP                     "ggml: use OpenMP"                                ON)
  ```

## 8. Processor-Specific Optimizations

### Cache Line Size Detection
The code detects and optimizes for different CPU cache line sizes.

**References:**
- `ggml.c`:
  ```c
  // Cache line size detection for different architectures
  #if defined(__APPLE__) && defined(__aarch64__)
      CACHE_LINE_SIZE = 128;
  #else
      CACHE_LINE_SIZE = 64;
  #endif
  ```

### CPU Feature Detection
Runtime detection of CPU features for optimal code paths.

**References:**
- `ggml-cpu.h`: Contains extensive CPU feature detection functions
  ```c
  // x86
  GGML_BACKEND_API int ggml_cpu_has_sse3       (void);
  GGML_BACKEND_API int ggml_cpu_has_ssse3      (void);
  GGML_BACKEND_API int ggml_cpu_has_avx        (void);
  GGML_BACKEND_API int ggml_cpu_has_avx_vnni   (void);
  GGML_BACKEND_API int ggml_cpu_has_avx2       (void);
  GGML_BACKEND_API int ggml_cpu_has_bmi2       (void);
  GGML_BACKEND_API int ggml_cpu_has_f16c       (void);
  GGML_BACKEND_API int ggml_cpu_has_fma        (void);
  GGML_BACKEND_API int ggml_cpu_has_avx512     (void);
  GGML_BACKEND_API int ggml_cpu_has_avx512_vbmi(void);
  GGML_BACKEND_API int ggml_cpu_has_avx512_vnni(void);
  GGML_BACKEND_API int ggml_cpu_has_avx512_bf16(void);
  GGML_BACKEND_API int ggml_cpu_has_amx_int8   (void);
  // ARM
  GGML_BACKEND_API int ggml_cpu_has_neon       (void);
  GGML_BACKEND_API int ggml_cpu_has_arm_fma    (void);
  GGML_BACKEND_API int ggml_cpu_has_fp16_va    (void);
  GGML_BACKEND_API int ggml_cpu_has_dotprod    (void);
  GGML_BACKEND_API int ggml_cpu_has_matmul_int8(void);
  GGML_BACKEND_API int ggml_cpu_has_sve        (void);
  GGML_BACKEND_API int ggml_cpu_get_sve_cnt    (void);
  GGML_BACKEND_API int ggml_cpu_has_sme        (void);
  // other
  GGML_BACKEND_API int ggml_cpu_has_riscv_v    (void);
  GGML_BACKEND_API int ggml_cpu_has_vsx        (void);
  GGML_BACKEND_API int ggml_cpu_has_vxe        (void);
  GGML_BACKEND_API int ggml_cpu_has_wasm_simd  (void);
  GGML_BACKEND_API int ggml_cpu_has_llamafile  (void);
  ```

## 9. Additional Architecture Support

### PowerPC/VSX Support
Support for IBM POWER architecture with VSX instructions.

**References:**
- `ggml.c`:
  ```c
  #if defined(__PPC__) || defined(__powerpc__) || defined(__powerpc64__)
  // PowerPC specific code
  #endif
  ```

## Compilation Systems and Platform Detection

The build system utilizes CMake with conditional compilation based on detected architectures and explicitly enabled features. The main configuration happens in:

- `CMakeLists.txt`: Central configuration for architecture-specific builds
- `ggml.c` and `ggml.h`: Contain architecture detection and specialized implementations

This architecture-specific code is carefully organized with preprocessor directives to ensure optimal code paths are selected based on the target platform and available CPU features.

## GPU and Non-CPU Acceleration

While not strictly CPU architecture features, llama.cpp also supports various GPU acceleration methods:

### CUDA Support
NVIDIA GPU acceleration through CUDA.

**References:**
- `CMakeLists.txt`: Configuration options for CUDA
  ```cmake
  # Referenced via transition helpers:
  llama_option_depr(FATAL_ERROR LLAMA_CUBLAS GGML_CUDA)
  llama_option_depr(WARNING LLAMA_CUDA GGML_CUDA)
  ```

### Metal Support
Apple GPU acceleration through Metal.

**References:**
- `CMakeLists.txt`: Configuration options for Metal
  ```cmake
  llama_option_depr(WARNING LLAMA_METAL GGML_METAL)
  llama_option_depr(WARNING LLAMA_METAL_EMBED_LIBRARY GGML_METAL_EMBED_LIBRARY)
  ```

### SYCL Support
Cross-platform acceleration through SYCL.

**References:**
- `CMakeLists.txt`: Configuration options for SYCL
  ```cmake
  llama_option_depr(WARNING LLAMA_SYCL GGML_SYCL)
  llama_option_depr(WARNING LLAMA_SYCL_F16 GGML_SYCL_F16)
  ```

### Kompute Support
Vulkan-based GPU acceleration.

**References:**
- `CMakeLists.txt`: Configuration options for Kompute
  ```cmake
  llama_option_depr(WARNING LLAMA_KOMPUTE GGML_KOMPUTE)
  ```

### CANN Support
Huawei Ascend AI processor support.

**References:**
- `CMakeLists.txt`: Configuration options for CANN
  ```cmake
  llama_option_depr(WARNING LLAMA_CANN GGML_CANN)
  ``` 