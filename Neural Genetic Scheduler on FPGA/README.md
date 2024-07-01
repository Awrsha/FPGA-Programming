# Neural Genetic Scheduler on FPGA

This project implements a hybrid neural network and genetic algorithm system for solving scheduling problems on an FPGA. The system leverages a neural network for evaluating solutions and a genetic algorithm for optimizing parameters.

## Table of Contents

- [Introduction](#introduction)
- [Features](#features)
- [Hardware Requirements](#hardware-requirements)
- [Software Requirements](#software-requirements)
- [Setup](#setup)
- [Usage](#usage)
- [File Descriptions](#file-descriptions)
- [License](#license)

## Introduction

This project demonstrates how to use a combination of a neural network and a genetic algorithm to solve scheduling problems on an FPGA. The neural network is used to evaluate the fitness of each solution in the population, and the genetic algorithm optimizes these solutions over several generations.

## Features

- **Parallelism:** Operations of the neural network and genetic algorithm are performed in parallel on the FPGA.
- **Flexibility:** Configurable parameters for both the neural network and the genetic algorithm to adapt to different scheduling problems.
- **Efficiency:** High performance and low power consumption due to FPGA implementation.

## Hardware Requirements

- FPGA compatible with PYNQ (e.g., Xilinx PYNQ-Z2)

## Software Requirements

- PYNQ library installed on your computer
- Python 3.6+
- Xilinx Vivado for synthesizing the VHDL code

## Setup

1. Clone this repository

2. Synthesize the VHDL code using Xilinx Vivado to generate the bitstream file `neural_genetic_scheduler.bit`.

3. Copy the bitstream file to your PYNQ board.

4. Install the necessary Python packages:
    ```bash
    pip install pynq numpy
    ```

## Usage

1. Initialize the scheduler with the bitstream path:
    ```python
    from neural_genetic_scheduler import NeuralGeneticScheduler

    scheduler = NeuralGeneticScheduler("neural_genetic_scheduler.bit")
    ```

2. Solve the scheduling problem:
    ```python
    best_solution, best_fitness = scheduler.solve_scheduling_problem(num_generations=100)
    print(f"Best Solution: {best_solution}")
    print(f"Best Fitness: {best_fitness}")
    ```

## File Descriptions

- **VHDL Files:**
  - `neuron.vhdl`: VHDL code for a single neuron.
  - `neural_layer.vhdl`: VHDL code for a neural network layer consisting of multiple neurons.
  - `genetic_algorithm.vhdl`: VHDL code for implementing the genetic algorithm.

- **Python File:**
  - `neural_genetic_scheduler.py`: Python code to manage and control the neural network and genetic algorithm on the FPGA.

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.