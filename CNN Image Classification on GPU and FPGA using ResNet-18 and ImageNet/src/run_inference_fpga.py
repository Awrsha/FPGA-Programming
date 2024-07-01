from pynq import Overlay
from pynq import allocate
import numpy as np
from pynq.lib.video import *
from pynq.lib.video.common import *
import cv2
import time

overlay = Overlay("resnet18_imagenet.bit")

def preprocess_image(image):
    image = cv2.resize(image, (224, 224))
    image = image.astype(np.float32) / 255.0
    image = (image - np.array([0.485, 0.456, 0.406])) / np.array([0.229, 0.224, 0.225])
    image = image.transpose((2, 0, 1))
    return image

def predict(image):
    preprocessed = preprocess_image(image)
    input_buffer = allocate(shape=(1, 3, 224, 224), dtype=np.float32)
    output_buffer = allocate(shape=(1, 1000), dtype=np.float32)
    
    input_buffer[0] = preprocessed
    
    dma = overlay.axi_dma_0
    
    start_time = time.time()
    dma.sendchannel.transfer(input_buffer)
    dma.recvchannel.transfer(output_buffer)
    dma.sendchannel.wait()
    dma.recvchannel.wait()
    end_time = time.time()
    
    inference_time = end_time - start_time
    result = output_buffer[0]
    return np.argmax(result), inference_time

frame_width = 640
frame_height = 480
videoIn = VideoIn(frame_width, frame_height)
videoOut = VideoOut(frame_width, frame_height)

videoIn.start()
videoOut.start()

with open('imagenet_classes.txt', 'r') as f:
    categories = [s.strip() for s in f.readlines()]

fpga_inference_times = []

try:
    for _ in range(100):
        frame = videoIn.readframe()
        if frame is not None:
            prediction, inference_time = predict(frame)
            class_name = categories[prediction]
            fpga_inference_times.append(inference_time)
            
            cv2.putText(frame, class_name, (10, 30), cv2.FONT_HERSHEY_SIMPLEX, 1, (0, 255, 0), 2)
            cv2.putText(frame, f"Time: {inference_time:.4f}s", (10, 60), cv2.FONT_HERSHEY_SIMPLEX, 1, (0, 255, 0), 2)
            
            videoOut.writeframe(frame)
except KeyboardInterrupt:
    print("Stopping...")
finally:
    videoIn.stop()
    videoOut.stop()

print("FPGA Results:")
print(f"Average Inference Time: {sum(fpga_inference_times)/len(fpga_inference_times):.4f}s")

print("\nComparison:")
print(f"GPU Average Inference Time: {sum(gpu_test_times)/len(gpu_test_times):.4f}s")
print(f"FPGA Average Inference Time: {sum(fpga_inference_times)/len(fpga_inference_times):.4f}s")
print(f"Speedup: {(sum(gpu_test_times)/len(gpu_test_times)) / (sum(fpga_inference_times)/len(fpga_inference_times)):.2f}x")