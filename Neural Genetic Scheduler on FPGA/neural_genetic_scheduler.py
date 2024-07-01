from pynq import Overlay
from pynq import allocate
import numpy as np
import time

class NeuralGeneticScheduler:
    def __init__(self, bitstream_path):
        self.overlay = Overlay(bitstream_path)
        self.neural_layer = self.overlay.neural_layer_0
        self.genetic_algorithm = self.overlay.genetic_algorithm_0
        
        self.population_size = 100
        self.chromosome_length = 32
        self.num_inputs = 8
        self.num_neurons = 4
        
    def initialize_weights(self):
        weights = np.random.rand(self.num_neurons, self.num_inputs).astype(np.float32)
        biases = np.random.rand(self.num_neurons).astype(np.float32)
        
        weights_buffer = allocate(shape=(self.num_neurons, self.num_inputs), dtype=np.float32)
        biases_buffer = allocate(shape=(self.num_neurons,), dtype=np.float32)
        
        np.copyto(weights_buffer, weights)
        np.copyto(biases_buffer, biases)
        
        self.neural_layer.write(0x10, weights_buffer.physical_address)
        self.neural_layer.write(0x18, biases_buffer.physical_address)
        
    def evaluate_population(self, population):
        input_buffer = allocate(shape=(self.population_size, self.num_inputs), dtype=np.float32)
        output_buffer = allocate(shape=(self.population_size, self.num_neurons), dtype=np.float32)
        
        np.copyto(input_buffer, population.reshape(self.population_size, self.num_inputs))
        
        self.neural_layer.write(0x20, input_buffer.physical_address)
        self.neural_layer.write(0x28, output_buffer.physical_address)
        self.neural_layer.write(0x00, 1)
        
        while (self.neural_layer.read(0x00) & 0x2) == 0:
            pass
        
        fitness = np.sum(output_buffer, axis=1)
        return fitness
    
    def run_genetic_algorithm(self, fitness):
        fitness_buffer = allocate(shape=(self.population_size,), dtype=np.int32)
        population_buffer = allocate(shape=(self.population_size, self.chromosome_length), dtype=np.int32)
        
        np.copyto(fitness_buffer, fitness.astype(np.int32))
        
        self.genetic_algorithm.write(0x10, fitness_buffer.physical_address)
        self.genetic_algorithm.write(0x18, population_buffer.physical_address)
        self.genetic_algorithm.write(0x00, 1)
        
        while (self.genetic_algorithm.read(0x00) & 0x2) == 0:
            pass
        
        return np.array(population_buffer)
    
    def solve_scheduling_problem(self, num_generations):
        self.initialize_weights()
        population = np.random.randint(0, 2, size=(self.population_size, self.chromosome_length))
        
        for generation in range(num_generations):
            fitness = self.evaluate_population(population)
            population = self.run_genetic_algorithm(fitness)
            
            best_solution = population[np.argmax(fitness)]
            best_fitness = np.max(fitness)
            
            print(f"Generation {generation}: Best Fitness = {best_fitness}")
        
        return best_solution, best_fitness

scheduler = NeuralGeneticScheduler("neural_genetic_scheduler.bit")
best_solution, best_fitness = scheduler.solve_scheduling_problem(num_generations=100)
print(f"Best Solution: {best_solution}")
print(f"Best Fitness: {best_fitness}")