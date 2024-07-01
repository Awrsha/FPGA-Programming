# CIFAR-10 Pattern Recognition on FPGA

This project demonstrates how to implement a deep learning algorithm on FPGA for pattern recognition using the CIFAR-10 dataset. The CIFAR-10 dataset consists of 32x32 color images in 10 different classes, making it suitable for pattern recognition tasks. We use PyTorch for training the model and the PYNQ platform to run the model on FPGA. PYNQ is an open-source framework that allows Python code to run directly on FPGA.

## Project Structure

1. **Training the Model in PyTorch** (`train_model.py`):
    - Load and preprocess the CIFAR-10 dataset.
    - Define and train a Convolutional Neural Network (CNN).
    - Quantize the trained model.
    - Export the model to ONNX and TensorFlow formats.

2. **Deploying the Model on FPGA** (`deploy_model_fpga.py`):
    - Load the bitstream for the FPGA.
    - Preprocess input images and make predictions using the FPGA.
    - Set up a video stream, process each frame, and display the prediction results.

## Prerequisites

- Python 3.x
- PyTorch
- torchvision
- PYNQ
- OpenCV
- ONNX
- ONNX-TensorFlow

## Getting Started

### Training the Model

1. **Install Dependencies**:
    ```sh
    pip install torch torchvision onnx onnx-tf
    ```

2. **Run the Training Script**:
    ```sh
    python train_model.py
    ```
    This script will:
    - Load the CIFAR-10 dataset.
    - Define and train the CNN.
    - Quantize the trained model.
    - Export the model to ONNX and TensorFlow formats.

3. **Generated Files**:
    - `cifar10_cnn.pth`: Trained PyTorch model.
    - `cifar10_cnn_quantized.pth`: Quantized PyTorch model.
    - `cifar10_cnn.onnx`: ONNX model.
    - `cifar10_cnn_tf`: TensorFlow model directory.

### Deploying the Model on FPGA

1. **Prepare the FPGA Bitstream**:
    - Generate the bitstream file (`cifar10_cnn.bit`) using Vivado HLS or similar tools.
    - Ensure the bitstream file is compatible with your PYNQ-compatible board (e.g., Xilinx PYNQ-Z1 or PYNQ-Z2).

2. **Install PYNQ and OpenCV**:
    ```sh
    pip install pynq opencv-python
    ```

3. **Run the Deployment Script**:
    ```sh
    python deploy_model_fpga.py
    ```
    This script will:
    - Load the bitstream for the FPGA.
    - Set up a video stream.
    - Preprocess each frame and make predictions using the FPGA.
    - Display the prediction results on each frame.

## File Structure

- `train_model.py`: Script for training and exporting the CNN model.
- `deploy_model_fpga.py`: Script for deploying the trained model on FPGA and processing video frames.
- `README.md`: Project documentation.

## Notes

- The FPGA deployment requires additional optimizations and adjustments for efficient performance.
- Ensure your PYNQ-compatible board and FPGA bitstream are correctly set up before running the deployment script.

## License

This project is licensed under the MIT License. See the LICENSE file for details.

## Acknowledgements

- CIFAR-10 dataset: [CIFAR-10](https://www.cs.toronto.edu/~kriz/cifar.html)
- PyTorch: [PyTorch](https://pytorch.org/)
- PYNQ: [PYNQ](http://www.pynq.io/)