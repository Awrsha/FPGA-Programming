# Reconfigurable CNN Architecture with Dynamic Pruning on FPGA
# Full Implementation

import torch
import torch.nn as nn
import torch.optim as optim
import torchvision
import numpy as np
from collections import OrderedDict
import json

# Hardware Configuration Parameters
class FPGAConfig:
    def __init__(self):
        self.available_dsp = 5760  # Example for Xilinx Virtex UltraScale+
        self.available_bram = 2160  # In terms of 36Kb blocks
        self.clock_freq = 200e6    # 200 MHz
        self.power_budget = 20     # 20W

# Dynamic Pruning Parameters        
class PruningConfig:
    def __init__(self):
        self.prune_rate = 0.5
        self.sensitivity_threshold = 0.1
        self.min_channels = 8
        
# Reconfigurable Layer Implementation
class ReconfigurableConv2d(nn.Module):
    def __init__(self, in_channels, out_channels, kernel_size, stride=1, padding=0):
        super(ReconfigurableConv2d, self).__init__()
        self.in_channels = in_channels
        self.out_channels = out_channels
        self.kernel_size = kernel_size
        self.stride = stride
        self.padding = padding
        
        # Main convolution layer
        self.conv = nn.Conv2d(in_channels, out_channels, kernel_size, 
                             stride=stride, padding=padding)
        
        # Mask for pruning
        self.mask = torch.ones_like(self.conv.weight.data)
        
        # Resource utilization tracking
        self.dsp_usage = self.calculate_dsp_usage()
        self.bram_usage = self.calculate_bram_usage()
        
    def calculate_dsp_usage(self):
        return self.in_channels * self.out_channels * self.kernel_size * self.kernel_size
        
    def calculate_bram_usage(self):
        return (self.in_channels * self.out_channels * self.kernel_size * self.kernel_size * 4) // 1024
        
    def forward(self, x):
        # Apply mask during forward pass
        masked_weight = self.conv.weight * self.mask
        return nn.functional.conv2d(x, masked_weight, self.conv.bias,
                                  stride=self.stride, padding=self.padding)
                                  
    def prune_channels(self, prune_rate):
        with torch.no_grad():
            weight_importance = torch.norm(self.conv.weight.data, dim=(1,2,3))
            num_to_prune = int(prune_rate * len(weight_importance))
            _, indices = torch.topk(weight_importance, num_to_prune, largest=False)
            self.mask[indices] = 0
            
# Reconfigurable CNN Model
class ReconfigurableCNN(nn.Module):
    def __init__(self, fpga_config):
        super(ReconfigurableCNN, self).__init__()
        self.fpga_config = fpga_config
        
        # Layer definitions
        self.layers = nn.ModuleDict({
            'conv1': ReconfigurableConv2d(3, 64, 3, padding=1),
            'conv2': ReconfigurableConv2d(64, 128, 3, padding=1),
            'conv3': ReconfigurableConv2d(128, 256, 3, padding=1),
            'conv4': ReconfigurableConv2d(256, 512, 3, padding=1)
        })
        
        self.pool = nn.MaxPool2d(2, 2)
        self.fc1 = nn.Linear(512 * 2 * 2, 1024)
        self.fc2 = nn.Linear(1024, 10)
        self.dropout = nn.Dropout(0.5)
        
    def forward(self, x):
        x = self.pool(torch.relu(self.layers['conv1'](x)))
        x = self.pool(torch.relu(self.layers['conv2'](x)))
        x = self.pool(torch.relu(self.layers['conv3'](x)))
        x = self.pool(torch.relu(self.layers['conv4'](x)))
        
        x = x.view(-1, 512 * 2 * 2)
        x = torch.relu(self.fc1(x))
        x = self.dropout(x)
        x = self.fc2(x)
        return x
        
    def get_resource_usage(self):
        total_dsp = sum(layer.dsp_usage for layer in self.layers.values())
        total_bram = sum(layer.bram_usage for layer in self.layers.values())
        return {'dsp': total_dsp, 'bram': total_bram}
        
# Dynamic Pruning Manager
class DynamicPruningManager:
    def __init__(self, model, pruning_config):
        self.model = model
        self.config = pruning_config
        self.sensitivity_map = {}
        
    def calculate_layer_sensitivity(self, layer, dataloader):
        original_accuracy = self.evaluate_accuracy(dataloader)
        original_mask = layer.mask.clone()
        
        layer.prune_channels(self.config.prune_rate)
        pruned_accuracy = self.evaluate_accuracy(dataloader)
        
        sensitivity = (original_accuracy - pruned_accuracy) / self.config.prune_rate
        layer.mask = original_mask
        
        return sensitivity
        
    def evaluate_accuracy(self, dataloader):
        self.model.eval()
        correct = 0
        total = 0
        
        with torch.no_grad():
            for inputs, labels in dataloader:
                outputs = self.model(inputs)
                _, predicted = outputs.max(1)
                total += labels.size(0)
                correct += predicted.eq(labels).sum().item()
                
        return correct / total
        
    def update_sensitivity_map(self, dataloader):
        for name, layer in self.model.layers.items():
            self.sensitivity_map[name] = self.calculate_layer_sensitivity(layer, dataloader)
            
    def prune_network(self):
        for name, layer in self.model.layers.items():
            if self.sensitivity_map[name] < self.config.sensitivity_threshold:
                layer.prune_channels(self.config.prune_rate)
                
# FPGA Resource Manager
class FPGAResourceManager:
    def __init__(self, fpga_config):
        self.config = fpga_config
        self.current_dsp = 0
        self.current_bram = 0
        
    def check_resource_constraints(self, model):
        resources = model.get_resource_usage()
        return (resources['dsp'] <= self.config.available_dsp and 
                resources['bram'] <= self.config.available_bram)
                
    def optimize_resource_allocation(self, model, pruning_manager):
        while not self.check_resource_constraints(model):
            # Find layer with lowest sensitivity
            min_sensitivity_layer = min(pruning_manager.sensitivity_map.items(),
                                     key=lambda x: x[1])[0]
            # Prune that layer
            model.layers[min_sensitivity_layer].prune_channels(
                pruning_manager.config.prune_rate)
                
# Bitstream Generator
class BitstreamGenerator:
    def __init__(self):
        self.header_size = 1024  # bytes
        self.configuration_words = []
        
    def generate_layer_bitstream(self, layer):
        config_word = {
            'type': 'conv2d',
            'in_channels': layer.in_channels,
            'out_channels': layer.out_channels,
            'kernel_size': layer.kernel_size,
            'stride': layer.stride,
            'padding': layer.padding,
            'weights': layer.conv.weight.data.numpy().tolist(),
            'mask': layer.mask.numpy().tolist()
        }
        return config_word
        
    def generate_model_bitstream(self, model):
        for name, layer in model.layers.items():
            self.configuration_words.append({
                'layer_name': name,
                'config': self.generate_layer_bitstream(layer)
            })
            
        return json.dumps(self.configuration_words)
        
# Main Training and Deployment Loop
def main():
    # Initialize configurations
    fpga_config = FPGAConfig()
    pruning_config = PruningConfig()
    
    # Create model and managers
    model = ReconfigurableCNN(fpga_config)
    pruning_manager = DynamicPruningManager(model, pruning_config)
    resource_manager = FPGAResourceManager(fpga_config)
    bitstream_generator = BitstreamGenerator()
    
    # Load dataset
    transform = torchvision.transforms.Compose([
        torchvision.transforms.ToTensor(),
        torchvision.transforms.Normalize((0.5, 0.5, 0.5), (0.5, 0.5, 0.5))
    ])
    
    trainset = torchvision.datasets.CIFAR10(root='./data', train=True,
                                          download=True, transform=transform)
    trainloader = torch.utils.data.DataLoader(trainset, batch_size=128,
                                            shuffle=True, num_workers=2)
    
    # Training loop
    criterion = nn.CrossEntropyLoss()
    optimizer = optim.SGD(model.parameters(), lr=0.01, momentum=0.9)
    
    for epoch in range(100):
        model.train()
        running_loss = 0.0
        
        for i, data in enumerate(trainloader, 0):
            inputs, labels = data
            optimizer.zero_grad()
            outputs = model(inputs)
            loss = criterion(outputs, labels)
            loss.backward()
            optimizer.step()
            
            running_loss += loss.item()
            
        # Periodic pruning and resource optimization
        if epoch % 10 == 0:
            pruning_manager.update_sensitivity_map(trainloader)
            pruning_manager.prune_network()
            resource_manager.optimize_resource_allocation(model, pruning_manager)
            
    # Generate final bitstream
    bitstream = bitstream_generator.generate_model_bitstream(model)
    
    # Save bitstream to file
    with open('fpga_configuration.bit', 'w') as f:
        f.write(bitstream)
        
if __name__ == "__main__":
    main()