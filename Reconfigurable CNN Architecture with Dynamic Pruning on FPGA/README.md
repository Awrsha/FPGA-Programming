# Reconfigurable CNN Architecture with Dynamic Pruning on FPGA 🧠

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![Python](https://img.shields.io/badge/python-3.8%2B-blue)
![PyTorch](https://img.shields.io/badge/PyTorch-2.0%2B-red)
![FPGA](https://img.shields.io/badge/FPGA-Virtex_UltraScale%2B-orange)

A high-performance, resource-efficient implementation of a Convolutional Neural Network (CNN) architecture with dynamic pruning capabilities deployed on FPGA hardware. This project optimizes neural network performance through runtime reconfiguration and intelligent resource management.

## Table of Contents
- [Architecture Overview](#architecture-overview)
- [Key Features](#key-features)
- [System Requirements](#system-requirements)
- [Installation](#installation)
- [Usage](#usage)
- [Component Breakdown](#component-breakdown)
- [Resource Management](#resource-management)
- [Performance Metrics](#performance-metrics)
- [Contributing](#contributing)
- [License](#license)

## Architecture Overview

```mermaid
graph TD
    A[Input Layer] --> B[Reconfigurable Conv2D Layers]
    B --> C[Dynamic Pruning Manager]
    C --> D[FPGA Resource Manager]
    D --> E[Bitstream Generator]
    E --> F[FPGA Deployment]
    
    subgraph "Runtime Optimization"
    C
    D
    end
    
    subgraph "Hardware Implementation"
    E
    F
    end
```

## Key Features

| Feature | Description | Priority |
|---------|-------------|----------|
| Dynamic Pruning | Runtime channel pruning based on sensitivity analysis | High |
| Resource Optimization | Intelligent DSP and BRAM allocation | High |
| Reconfigurable Layers | Adaptable network architecture | Medium |
| Bitstream Generation | Automated FPGA configuration generation | Medium |
| Performance Monitoring | Real-time resource utilization tracking | Low |

## System Requirements

### Software Dependencies
```mermaid
graph LR
    A[Python 3.8+] --> B[PyTorch 2.0+]
    B --> C[torchvision]
    B --> D[numpy]
    A --> E[JSON]
```

### Hardware Requirements
- FPGA: Xilinx Virtex UltraScale+
- DSP Slices: 5760
- BRAM: 2160 (36Kb blocks)
- Clock Frequency: 200 MHz
- Power Budget: 20W

## Component Breakdown

### Layer Architecture
```mermaid
classDiagram
    class ReconfigurableConv2d {
        +int in_channels
        +int out_channels
        +int kernel_size
        +calculate_dsp_usage()
        +prune_channels()
    }
    
    class DynamicPruningManager {
        +dict sensitivity_map
        +calculate_layer_sensitivity()
        +update_sensitivity_map()
    }
    
    class FPGAResourceManager {
        +check_resource_constraints()
        +optimize_resource_allocation()
    }
    
    ReconfigurableConv2d --> DynamicPruningManager
    DynamicPruningManager --> FPGAResourceManager
```

## Resource Management

### DSP Allocation Strategy
```mermaid
pie
    title "DSP Resource Distribution"
    "Conv Layer 1" : 25
    "Conv Layer 2" : 30
    "Conv Layer 3" : 25
    "Conv Layer 4" : 20
```

### Memory Hierarchy
| Level | Type | Size | Latency |
|-------|------|------|----------|
| L1 Cache | BRAM | 256KB | 1 cycle |
| L2 Cache | BRAM | 1MB | 2-3 cycles |
| External | DDR4 | 16GB | 100+ cycles |

## Performance Metrics

### Pruning Efficiency
```mermaid
gantt
    title Pruning Timeline
    dateFormat  YYYY-MM-DD
    section Layer 1
    Initial Pruning    :2024-01-01, 7d
    Fine-tuning       :7d
    section Layer 2
    Initial Pruning    :2024-01-08, 7d
    Fine-tuning       :7d
```

### Resource Utilization
| Resource | Available | Used | Utilization |
|----------|-----------|------|-------------|
| DSP | 5760 | 4320 | 75% |
| BRAM | 2160 | 1512 | 70% |
| LUT | 1.3M | 850K | 65% |
| FF | 2.6M | 1.5M | 58% |

## Implementation Flow

```mermaid
sequenceDiagram
    participant ML as Model Loading
    participant DP as Dynamic Pruning
    participant RM as Resource Manager
    participant BG as Bitstream Gen
    participant FPGA as FPGA
    
    ML->>DP: Initialize Model
    DP->>RM: Check Resources
    RM->>DP: Resource Constraints
    DP->>DP: Prune Layers
    DP->>BG: Optimized Model
    BG->>FPGA: Configure Hardware
```

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE.md](LICENSE.md) file for details.
