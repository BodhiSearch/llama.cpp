# CPU Architecture Support and Binary Distribution Strategy

## Executive Summary

After thorough research and analysis of CPU architecture support in llama.cpp, we have decided to:

1. Ship AVX2+FMA as the default binary compilation target
2. Provide specialized binaries for other CPU feature sets via on-demand download
3. Focus on CPU generation-specific optimizations for maximum performance

This document outlines the specific binary variants we will build and their target CPU architectures.

## CPU Architecture Landscape

Modern x86/x86-64 CPUs support multiple generations of SIMD (Single Instruction, Multiple Data) instruction sets, with each generation adding new capabilities. Our binary distribution strategy is designed to leverage these capabilities while maintaining compatibility.

### Key CPU Feature Characteristics

1. **Backward Compatibility**
   - Newer CPUs fully support all older instruction sets
   - AVX-512 CPUs can run AVX2 code perfectly
   - AVX2 CPUs can run AVX code perfectly

2. **Performance Considerations**
   - Newer instruction sets generally offer higher performance for optimized code
   - Some CPUs may throttle when executing advanced instructions (especially AVX-512)
   - Thermal and power characteristics vary by workload and specific CPU model

3. **Market Distribution**
   - AVX2+FMA is now widely deployed (majority of CPUs from 2015 onwards)
   - AVX-512 has limited deployment (high-end Intel since 2017, AMD since 2022)
   - Some low-power or budget CPUs may only support AVX or even just SSE4.2

## Binary Distribution Strategy

### Default Binary: Haswell (AVX2+FMA)

We have selected Haswell architecture (AVX2+FMA) as our default binary target for the following reasons:

1. **Widespread Compatibility**
   - Covers the vast majority of CPUs in active use (7+ years)
   - Works on both Intel and AMD systems
   - Provides good performance without excessive specialization

2. **Performance/Compatibility Balance**
   - Offers significant performance benefits over AVX-only code
   - Avoids the deployment challenges of AVX-512
   - Includes FMA instructions for important performance gains

3. **Future-Proof**
   - Will remain compatible with all new x86-64 CPUs due to backward compatibility
   - Represents a stable instruction set with universal support from CPU vendors

### Binary Variants

We will build the following binary variants, organized by target CPU generation:

| Binary Name | Target CPU Generation | CPU Feature Set |
|-------------|----------------------|-------------|
| llama-generic | Any x86-64 CPU | No specific SIMD optimizations |
| llama-sse42 | Core 2, Nehalem, early AMD | SSE4.2 |
| llama-sandybridge | Sandy Bridge, Ivy Bridge | AVX |
| llama-haswell | Haswell, Broadwell, Skylake (non-X), Zen 1-3 | AVX, F16C, AVX2, FMA |
| llama-skylakex | Skylake-X, Cascade Lake, Cooper Lake | AVX, F16C, AVX2, FMA, AVX512F, AVX512BW, AVX512CD, AVX512DQ, AVX512VL |
| llama-icelake | Ice Lake, Tiger Lake | AVX, F16C, AVX2, FMA, AVX512F, AVX512BW, AVX512CD, AVX512DQ, AVX512VL, AVX512VBMI, AVX512VNNI |
| llama-alderlake | Alder Lake, Raptor Lake | AVX, F16C, AVX2, FMA, AVX_VNNI (no AVX-512) |
| llama-sapphirerapids | Sapphire Rapids | AVX, F16C, AVX2, FMA, AVX512F, AVX512BW, AVX512CD, AVX512DQ, AVX512VL, AVX512VBMI, AVX512VNNI, AVX512_BF16, AMX_TILE, AMX_INT8, AMX_BF16 |
| llama-zen4 | AMD Zen 4 (Ryzen 7000 series) | AVX, F16C, AVX2, FMA, AVX512F (AMD implementation) |

### CPU Generation Mapping

For user reference, here's a mapping of specific CPU models to the appropriate binary:

**Intel CPUs:**
- 2nd/3rd Gen Core (Sandy Bridge, Ivy Bridge): Use llama-sandybridge
- 4th-10th Gen Core i3/i5/i7 (non-HEDT): Use llama-haswell
- 6th-10th Gen Core i9/HEDT (Skylake-X): Use llama-skylakex
- 11th Gen Core (Ice Lake, Tiger Lake): Use llama-icelake
- 12th/13th Gen Core (Alder Lake, Raptor Lake): Use llama-alderlake
- 4th Gen Xeon Scalable (Sapphire Rapids): Use llama-sapphirerapids
- Any CPU older than Sandy Bridge: Use llama-sse42 or llama-generic

**AMD CPUs:**
- Ryzen 1000-5000 series (Zen 1-3): Use llama-haswell
- Ryzen 7000 series (Zen 4): Use llama-zen4
- Pre-Ryzen CPUs: Use llama-sandybridge, llama-sse42, or llama-generic depending on age

## Other Supported CPU Architectures

While our binary distribution strategy focuses on x86/x86-64 architectures, llama.cpp supports several other CPU architectures. These are not included in the current binary distribution strategy but are fully supported by the codebase:

### ARM Architecture
- **NEON SIMD Extensions**: Used in mobile and embedded ARM processors
- **SVE (Scalable Vector Extension)**: Found in newer ARM server processors
- **SME (Scalable Matrix Extension)**: Extension to SVE adding matrix operations
- **Apple Silicon**: Optimizations for Apple M-series chips

### RISC-V Architecture
- **RVV (RISC-V Vector Extension)**: SIMD instructions for RISC-V processors

### LOONGARCH Architecture
- **LSX/LASX (LOONGARCH SIMD Extensions)**: SIMD instructions for LOONGARCH processors

### S390x Architecture
- **VXE (Vector Extension)**: SIMD instructions for S390x processors

### PowerPC Architecture
- **VSX (Vector Scalar Extension)**: SIMD instructions for IBM POWER processors

Users on these platforms can compile llama.cpp from source with the appropriate build flags to ensure optimal performance for their specific architecture.

## Implementation Architecture

The distribution system will be structured as follows:

1. **Initial Deployment**
   - Ship only the Haswell (AVX2+FMA) binary by default
   - Implement CPU feature detection to determine if alternative binary is needed

2. **On-Demand Download**
   - Download appropriate specialized binary when needed
   - For high-end CPUs with AVX-512 or newer features, offer performance-optimized binaries

3. **Binary Management**
   - Store alternative binaries in user-specific application data directory
   - Track binary versions to handle application updates

4. **Fallback Mechanism**
   - Implement progressive fallback when optimal binary is unavailable
   - Ensure graceful handling of download failures

### Potential Challenges with Downloadable Binaries

1. **Corporate Environment Limitations**
   - Corporate firewalls may block on-demand downloads
   - Offline environments can't access alternative binaries
   
   **Possible solution:** Provide an all-in-one package option for enterprise deployment

2. **Download Experience**
   - Users may experience delays during first-run when optimal binary is downloading
   
   **Possible solution:** Implement background downloading with clear progress indication

3. **Compatibility Verification**
   - Ensuring the downloaded binary is compatible with the user's exact system
   
   **Possible solution:** Implement verification checks before executing downloaded binaries

## Testing Strategy

Implement thorough testing of the binary distribution mechanism:

1. **Hardware Test Matrix**
   - Test on CPUs representing each major instruction set generation
   - Verify correct binary selection on different hardware

2. **Failure Mode Testing**
   - Test behavior when downloads fail
   - Verify fallback mechanisms work properly

3. **Performance Validation**
   - Benchmark each binary on appropriate hardware
   - Confirm performance benefits of specialized binaries

## Conclusion

Our decision to ship the Haswell (AVX2+FMA) binary as the default with specialized variants available on-demand represents the best balance of performance, compatibility, and maintainability. This approach:

1. Supports the vast majority of current CPUs with good performance
2. Provides optimized builds for both older and newer hardware
3. Minimizes initial download size for most users
4. Offers flexible deployment options for various environments

By targeting specific CPU generations with optimized binaries, we ensure the best possible performance across all supported platforms and processors. 