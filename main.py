import os
import cv2
import numpy as np
import tensorflow as tf
from tensorflow.keras.models import Sequential
from tensorflow.keras.layers import TimeDistributed, LSTM, Dense, Dropout, Conv2D, MaxPooling2D, Flatten
from tensorflow.keras.optimizers import Adam
from tensorflow.keras.utils import to_categorical
from sklearn.model_selection import train_test_split

NUM_CLASSES = 6
SEQUENCE_LENGTH = 20
IMAGE_HEIGHT = 120
IMAGE_WIDTH = 160
CHANNELS = 3

!wget http://www.nada.kth.se/cvap/actions/walking.zip
!unzip walking.zip -d kth_dataset

def process_video(video_path):
    cap = cv2.VideoCapture(video_path)
    frames = []
    for _ in range(SEQUENCE_LENGTH):
        ret, frame = cap.read()
        if ret:
            frame = cv2.resize(frame, (IMAGE_WIDTH, IMAGE_HEIGHT))
            frame = frame / 255.0
            frames.append(frame)
        else:
            frames.append(np.zeros((IMAGE_HEIGHT, IMAGE_WIDTH, CHANNELS)))
    cap.release()
    return np.array(frames)

X = []
y = []

for action in os.listdir('kth_dataset'):
    if os.path.isdir(os.path.join('kth_dataset', action)):
        for video in os.listdir(os.path.join('kth_dataset', action)):
            video_path = os.path.join('kth_dataset', action, video)
            sequence = process_video(video_path)
            X.append(sequence)
            y.append(action)

X = np.array(X)
y = np.array(y)

label_map = {label: i for i, label in enumerate(np.unique(y))}
y = np.array([label_map[label] for label in y])
y = to_categorical(y, num_classes=NUM_CLASSES)

X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42)

model = Sequential([
    TimeDistributed(Conv2D(32, (3, 3), activation='relu'), input_shape=(SEQUENCE_LENGTH, IMAGE_HEIGHT, IMAGE_WIDTH, CHANNELS)),
    TimeDistributed(MaxPooling2D((2, 2))),
    TimeDistributed(Conv2D(64, (3, 3), activation='relu')),
    TimeDistributed(MaxPooling2D((2, 2))),
    TimeDistributed(Conv2D(128, (3, 3), activation='relu')),
    TimeDistributed(MaxPooling2D((2, 2))),
    TimeDistributed(Flatten()),
    LSTM(256, return_sequences=True),
    LSTM(128),
    Dense(64, activation='relu'),
    Dropout(0.5),
    Dense(NUM_CLASSES, activation='softmax')
])

model.compile(optimizer=Adam(learning_rate=0.001), loss='categorical_crossentropy', metrics=['accuracy'])

history = model.fit(X_train, y_train, epochs=50, batch_size=32, validation_split=0.2)

test_loss, test_acc = model.evaluate(X_test, y_test)
print(f'Test accuracy: {test_acc}')

model.save('motion_detection_model.h5')

converter = tf.lite.TFLiteConverter.from_keras_model(model)
tflite_model = converter.convert()

with open('motion_detection_model.tflite', 'wb') as f:
    f.write(tflite_model)

def predict_video(video_path):
    sequence = process_video(video_path)
    sequence = np.expand_dims(sequence, axis=0)
    prediction = model.predict(sequence)
    predicted_class = np.argmax(prediction[0])
    return list(label_map.keys())[list(label_map.values()).index(predicted_class)]

new_video_path = 'path_to_new_video.avi'
predicted_action = predict_video(new_video_path)
print(f'Predicted action: {predicted_action}')