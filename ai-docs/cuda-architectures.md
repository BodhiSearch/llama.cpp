```
set(CMAKE_CUDA_ARCHITECTURES 50)  # Maxwell: GTX 750, 750 Ti
set(CMAKE_CUDA_ARCHITECTURES 52)  # Maxwell: GTX 960, 970, 980, TITAN X
set(CMAKE_CUDA_ARCHITECTURES 60)  # Pascal: GTX 1060, 1070, 1080, TITAN X
set(CMAKE_CUDA_ARCHITECTURES 61)  # Pascal: GTX 1050, 1050 Ti
set(CMAKE_CUDA_ARCHITECTURES 70)  # Volta: V100
set(CMAKE_CUDA_ARCHITECTURES 72)  # Turing: RTX 2060, 2070, 2080, TITAN RTX
set(CMAKE_CUDA_ARCHITECTURES 75)  # Turing: GTX 1650, 1660 Ti
set(CMAKE_CUDA_ARCHITECTURES 80)  # Ampere: A100, RTX 3060, 3070, 3080, 3090
set(CMAKE_CUDA_ARCHITECTURES 86)  # Ampere: RTX 3050, 3060 Ti, A2
set(CMAKE_CUDA_ARCHITECTURES 89)  # Ada Lovelace: RTX 4090, 4080, 4070 Ti
set(CMAKE_CUDA_ARCHITECTURES 90)  # Hopper: H100
```

Based on the CUDA architectures listed in ai-docs/cuda-architectures.md, we can group them by CUDA compute capability compatibility:

For CUDA 12.x (our current version 12.6.2), we can support these architectures:

1. Latest GPUs (can be combined):
```
89 - Ada Lovelace (RTX 4000 series)
90 - Hopper (H100)
```

2. Recent GPUs (can be combined):
```
80 - Ampere (A100, RTX 3060/70/80/90)
86 - Ampere (RTX 3050/3060Ti, A2)
```

3. Older but still supported (can be combined):
```
70 - Volta (V100)
72 - Turing (RTX 2060/70/80)
75 - Turing (GTX 1650/1660Ti)
```

Not supported in CUDA 12.x:
```
50/52 - Maxwell
60/61 - Pascal
```

For optimal performance and binary size, it's best to group architectures that are likely to be used together. That's why combining 89 and 90 makes sense as they represent the latest generation GPUs.

Would you like me to suggest different architecture combinations for the matrix strategy?
