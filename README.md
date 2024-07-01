# Motion Detection using Deep Learning and FPGA

This project aims to detect human actions from video sequences using a deep learning model implemented in TensorFlow/Keras and its deployment on an FPGA using VHDL. The project includes a Python script for training the model and VHDL code for running inference on the trained model.

## Table of Contents
- [Introduction](#introduction)
- [Dataset](#dataset)
- [Model Training](#model-training)
- [Model Conversion](#model-conversion)
- [FPGA Implementation](#fpga-implementation)
- [Usage](#usage)
- [Requirements](#requirements)
- [Acknowledgments](#acknowledgments)

## Introduction

This project integrates machine learning with hardware design to detect actions in video sequences. It consists of:
1. A Python script (`main.py`) for training an action recognition model using the KTH dataset.
2. VHDL code (`motion_detection.vhd` and `TFLiteMicro.vhd`) for implementing the trained model on an FPGA.

## Dataset

The project uses the KTH Human Actions Dataset. The dataset consists of six different types of human actions: walking, jogging, running, boxing, hand waving, and hand clapping.

Download and extract the dataset:
```bash
wget http://www.nada.kth.se/cvap/actions/walking.zip
unzip walking.zip -d kth_dataset
```

## Model Training

The model is trained using TensorFlow/Keras. The architecture consists of a combination of Convolutional Neural Networks (CNN) and Long Short-Term Memory (LSTM) layers to process video frames and sequence information.

### Training Script

The training script is `main.py`, which includes:
- Video processing and data preparation
- Model definition and training
- Model evaluation
- Conversion to TensorFlow Lite format

Run the training script:
```bash
python main.py
```

## Model Conversion

The trained model is converted to TensorFlow Lite format for deployment on the FPGA:
```python
converter = tf.lite.TFLiteConverter.from_keras_model(model)
tflite_model = converter.convert()

with open('motion_detection_model.tflite', 'wb') as f:
    f.write(tflite_model)
```

## FPGA Implementation

### VHDL Code

Two VHDL files are provided for FPGA implementation:
1. `motion_detection.vhd`: Main entity handling video frame processing.
2. `TFLiteMicro.vhd`: Implements a simplified inference engine for the TensorFlow Lite model.

### Components

- `ArtificialVisionSensor`: Captures video frames and buffers them for processing.
- `TFLiteMicro`: Processes buffered frames using the TensorFlow Lite model and outputs detected actions.

### Simulation

Use an FPGA development environment (e.g., Xilinx Vivado or Intel Quartus) to simulate and test the VHDL code. Ensure all dependencies and constraints are correctly set up for your FPGA board.

## Usage

### Predict Action in a New Video

After training, use the `predict_video` function to predict actions in new video files:
```python
new_video_path = 'path_to_new_video.avi'
predicted_action = predict_video(new_video_path)
print(f'Predicted action: {predicted_action}')
```

### FPGA Deployment

1. Synthesize the VHDL code and upload it to your FPGA.
2. Provide video input and monitor the FPGA's output for detected actions.

## Requirements

### Python Environment

- Python 3.x
- TensorFlow
- OpenCV
- NumPy

Install dependencies:
```bash
pip install tensorflow opencv-python numpy
```

### FPGA Environment

- FPGA development environment (e.g., Xilinx Vivado, Intel Quartus)
- FPGA board

## Acknowledgments

- The KTH Human Actions Dataset provided by the Computational Vision and Active Perception Lab.
- TensorFlow and Keras for providing powerful deep learning tools.
- The FPGA development community for resources and support.