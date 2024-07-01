import pynq
from pynq import Overlay
from pynq import allocate
import numpy as np
import time

class DistributedNeuralNetwork:
    def __init__(self, num_fpgas, bitstream_path):
        self.num_fpgas = num_fpgas
        self.fpgas = [Overlay(bitstream_path) for _ in range(num_fpgas)]
        self.systolic_arrays = [fpga.systolic_array_0 for fpga in self.fpgas]
        self.data_width = 16
        self.array_size = 4

    def distribute_matrix(self, matrix):
        rows, cols = matrix.shape
        fpga_rows = rows // self.num_fpgas
        distributed = []
        for i in range(self.num_fpgas):
            start = i * fpga_rows
            end = (i + 1) * fpga_rows
            distributed.append(matrix[start:end])
        return distributed

    def matrix_multiply(self, A, B):
        distributed_A = self.distribute_matrix(A)
        result = []

        for i, A_part in enumerate(distributed_A):
            fpga = self.fpgas[i]
            systolic_array = self.systolic_arrays[i]

            A_buffer = allocate(shape=A_part.shape, dtype=np.int16)
            B_buffer = allocate(shape=B.shape, dtype=np.int16)
            C_buffer = allocate(shape=(A_part.shape[0], B.shape[1]), dtype=np.int32)

            np.copyto(A_buffer, A_part)
            np.copyto(B_buffer, B)

            start_time = time.time()

            for i in range(0, A_part.shape[0], self.array_size):
                for j in range(0, B.shape[1], self.array_size):
                    weights = A_buffer[i:i+self.array_size, :].flatten()
                    activations = B_buffer[:, j:j+self.array_size].T.flatten()

                    systolic_array.write(0x10, weights.tobytes())
                    systolic_array.write(0x20, activations.tobytes())
                    systolic_array.write(0x00, 1)

                    while (systolic_array.read(0x00) & 0x2) == 0:
                        pass

                    partial_result = np.frombuffer(systolic_array.read(0x30, self.array_size * 4), dtype=np.int32)
                    C_buffer[i:i+self.array_size, j:j+self.array_size] = partial_result.reshape((self.array_size, self.array_size))

            end_time = time.time()
            print(f"FPGA {i} computation time: {end_time - start_time:.4f} seconds")

            result.append(np.array(C_buffer))

        return np.vstack(result)

    def forward_pass(self, input_data, weights):
        result = input_data
        for layer_weights in weights:
            result = self.matrix_multiply(result, layer_weights)
            result = np.maximum(result, 0)  # ReLU activation
        return result

num_fpgas = 4
bitstream_path = "systolic_array.bit"
dnn = DistributedNeuralNetwork(num_fpgas, bitstream_path)

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

start_time = time.time()
output = dnn.forward_pass(input_data, weights)
end_time = time.time()

print(f"Total computation time: {end_time - start_time:.4f} seconds")
print(f"Output shape: {output.shape}")