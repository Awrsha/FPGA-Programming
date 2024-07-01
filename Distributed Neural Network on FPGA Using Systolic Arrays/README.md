# Distributed Neural Network on FPGA Using Systolic Arrays

This project demonstrates the implementation of a distributed neural network architecture using systolic arrays on multiple FPGAs. The architecture is optimized for matrix operations, which are common in neural networks, and is scalable across several FPGAs.

## Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Setup](#setup)
- [Files](#files)
- [Usage](#usage)
- [Future Enhancements](#future-enhancements)
- [License](#license)

## Overview

This project leverages systolic arrays to perform efficient matrix multiplications, a core operation in neural networks, distributed across multiple FPGAs. The systolic array architecture allows for parallel processing, enhancing computational efficiency and scalability.

## Architecture

The project includes the following components:

1. **Processing Element (PE):** A basic unit in the systolic array that performs matrix multiplications.
2. **Systolic Array:** A 4x4 array of PEs for parallel matrix operations.
3. **Distributed Neural Network Controller:** A Python class that manages the distribution of computations across multiple FPGAs and aggregates the results.

## Setup

### Prerequisites

- Xilinx Vivado (for synthesizing VHDL code)
- PYNQ-compatible FPGAs (e.g., Xilinx PYNQ-Z2)
- Python 3.x
- PYNQ library

### Installation

1. **Clone the repository**

2. **Generate the bitstream:**
   - Open `ProcessingElement.vhdl` and `SystolicArray.vhdl` in Vivado.
   - Generate the bitstream files (`systolic_array.bit`).

3. **Setup Python environment:**
   ```sh
   pip install pynq numpy
   ```

4. **Copy bitstream to FPGAs:**
   - Load the generated bitstream onto each PYNQ-compatible FPGA.

## Files

- **`ProcessingElement.vhdl`**: VHDL code for the processing element in the systolic array.
- **`SystolicArray.vhdl`**: VHDL code for a 4x4 systolic array of processing elements.
- **`DistributedNeuralNetwork.py`**: Python code for managing distributed matrix operations across multiple FPGAs.

## Usage

1. **Import the DistributedNeuralNetwork class:**
   ```python
   from DistributedNeuralNetwork import DistributedNeuralNetwork
   ```

2. **Initialize the neural network:**
   ```python
   num_fpgas = 4
   bitstream_path = "systolic_array.bit"
   dnn = DistributedNeuralNetwork(num_fpgas, bitstream_path)
   ```

3. **Define input data and weights:**
   ```python
   input_size = 1024
   hidden_size = 512
   output_size = 10
   batch_size = 32

   input_data = np.random.rand(batch_size, input_size).astype(np.float16)
   weights = [
       np.random.rand(input_size, hidden_size).astype(np.float16),
       np.random.rand(hidden_size, hidden_size).astype(np.float16),
       np.random.rand(hidden_size, output_size).astype(np.float16)
   ]
   ```

4. **Perform forward pass:**
   ```python
   output = dnn.forward_pass(input_data, weights)
   print(f"Output shape: {output.shape}")
   ```

## Future Enhancements

- Implement optimization algorithms (e.g., Adam, SGD) directly on the FPGA.
- Add buffering to reduce communication latency.
- Implement weight compression techniques to reduce bandwidth requirements.
- Add support for various neural network layers (e.g., convolutional layers).

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.
