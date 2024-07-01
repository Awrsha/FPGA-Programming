# CNN Image Classification on GPU and FPGA using ResNet-18 and ImageNet

This project compares the performance of Convolutional Neural Networks (CNNs) on GPU and FPGA for image classification tasks. We use the ResNet-18 architecture and the ImageNet dataset to train the model on a GPU and deploy it on an FPGA.

## Table of Contents

- [Project Overview](#project-overview)
- [Directory Structure](#directory-structure)
- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Training the Model](#training-the-model)
- [Running Inference on FPGA](#running-inference-on-fpga)
- [Results](#results)
- [Notes](#notes)
- [License](#license)

## Project Overview

The goal of this project is to:
1. Train a ResNet-18 model on the ImageNet dataset using a GPU.
2. Quantize the trained model for efficient deployment.
3. Export the model to ONNX format.
4. Deploy the model on an FPGA and run inference.
5. Compare the performance of the model on GPU and FPGA in terms of inference time and accuracy.

## Directory Structure

```
cnn-gpu-fpga-comparison/
├── data/
│   └── imagenet_classes.txt
├── src/
│   ├── train_and_prepare_model.py
│   ├── run_inference_fpga.py
│   ├── resnet18_imagenet.bit
│   └── resnet18_imagenet.pth
├── README.md
└── requirements.txt
```

### Files Description

- `data/imagenet_classes.txt`: Contains the names of the 1000 classes of the ImageNet dataset.
- `src/train_and_prepare_model.py`: Script to train the ResNet-18 model on GPU, quantize the model, and export it to ONNX format.
- `src/run_inference_fpga.py`: Script to run the trained model on an FPGA and compare the inference times with those on GPU.
- `src/resnet18_imagenet.bit`: Bitstream file for the FPGA implementation.
- `src/resnet18_imagenet.pth`: Trained PyTorch model file.

## Prerequisites

- Python 3.8+
- PyTorch
- torchvision
- numpy
- OpenCV
- PYNQ library
- ONNX
- TensorFlow

## Installation

1. Clone the repository

2. Install the required packages:
   ```bash
   pip install -r requirements.txt
   ```

3. Download the ImageNet dataset and place it in the `data` directory.

## Training the Model

To train the ResNet-18 model on the ImageNet dataset using a GPU, run the following command:

```bash
python src/train_and_prepare_model.py
```

This script will:
1. Train the ResNet-18 model.
2. Quantize the model for efficient deployment.
3. Export the model to ONNX format.
4. Save the trained model files.

## Running Inference on FPGA

Ensure that the FPGA board is connected and the bitstream file (`resnet18_imagenet.bit`) is correctly loaded. Then, run the following command:

```bash
python src/run_inference_fpga.py
```

This script will run the inference on the FPGA and compare the performance with the GPU.

## Results

The results of the comparison, including average training time, inference time, and accuracy on GPU, and average inference time on FPGA, will be printed to the console.

## Notes

- The FPGA bitstream file (`resnet18_imagenet.bit`) should be generated using Vivado HLS with the appropriate settings for your FPGA board.
- You may need to adjust the paths and settings in the scripts according to your specific setup and hardware.
- This project assumes familiarity with FPGA programming and the PYNQ library for Python.

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.