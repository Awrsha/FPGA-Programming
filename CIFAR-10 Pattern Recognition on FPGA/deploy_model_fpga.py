from pynq import Overlay
from pynq import allocate
import numpy as np
from pynq.lib.video import *
from pynq.lib.video.common import *
import cv2

overlay = Overlay("cifar10_cnn.bit")

def preprocess_image(image):
    image = cv2.resize(image, (32, 32))
    image = image.astype(np.float32) / 255.0
    image = (image - 0.5) / 0.5
    image = image.transpose((2, 0, 1))
    return image

def predict(image):
    preprocessed = preprocess_image(image)
    input_buffer = allocate(shape=(1, 3, 32, 32), dtype=np.float32)
    output_buffer = allocate(shape=(1, 10), dtype=np.float32)
    
    input_buffer[0] = preprocessed
    
    dma = overlay.axi_dma_0
    dma.sendchannel.transfer(input_buffer)
    dma.recvchannel.transfer(output_buffer)
    dma.sendchannel.wait()
    dma.recvchannel.wait()
    
    result = output_buffer[0]
    return np.argmax(result)

frame_width = 640
frame_height = 480
videoIn = VideoIn(frame_width, frame_height)
videoOut = VideoOut(frame_width, frame_height)

videoIn.start()
videoOut.start()

classes = ['airplane', 'automobile', 'bird', 'cat', 'deer', 'dog', 'frog', 'horse', 'ship', 'truck']

try:
    while True:
        frame = videoIn.readframe()
        if frame is not None:
            prediction = predict(frame)
            class_name = classes[prediction]
            
            cv2.putText(frame, class_name, (10, 30), cv2.FONT_HERSHEY_SIMPLEX, 1, (0, 255, 0), 2)
            
            videoOut.writeframe(frame)
except KeyboardInterrupt:
    print("Stopping...")
finally:
    videoIn.stop()
    videoOut.stop()