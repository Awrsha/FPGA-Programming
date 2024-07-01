import torch
import torchvision
import torchvision.transforms as transforms
import torch.nn as nn
import torch.optim as optim
from torch.utils.data import DataLoader
from torchvision.models import resnet18
import time
import onnx
from onnx_tf.backend import prepare

device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
batch_size = 64
num_epochs = 10
learning_rate = 0.001

transform = transforms.Compose([
    transforms.Resize(256),
    transforms.CenterCrop(224),
    transforms.ToTensor(),
    transforms.Normalize(mean=[0.485, 0.456, 0.406], std=[0.229, 0.224, 0.225]),
])

trainset = torchvision.datasets.ImageNet(root='./data', split='train', download=True, transform=transform)
testset = torchvision.datasets.ImageNet(root='./data', split='val', download=True, transform=transform)

train_loader = DataLoader(trainset, batch_size=batch_size, shuffle=True, num_workers=4)
test_loader = DataLoader(testset, batch_size=batch_size, shuffle=False, num_workers=4)

model = resnet18(pretrained=True)
model = model.to(device)

criterion = nn.CrossEntropyLoss()
optimizer = optim.Adam(model.parameters(), lr=learning_rate)

def train(model, train_loader, criterion, optimizer, device):
    model.train()
    running_loss = 0.0
    correct = 0
    total = 0
    start_time = time.time()

    for batch_idx, (inputs, targets) in enumerate(train_loader):
        inputs, targets = inputs.to(device), targets.to(device)
        
        optimizer.zero_grad()
        outputs = model(inputs)
        loss = criterion(outputs, targets)
        loss.backward()
        optimizer.step()

        running_loss += loss.item()
        _, predicted = outputs.max(1)
        total += targets.size(0)
        correct += predicted.eq(targets).sum().item()

        if batch_idx % 100 == 99:
            print(f'Batch: {batch_idx+1}, Loss: {running_loss/100:.3f}, Acc: {100.*correct/total:.2f}%')
            running_loss = 0.0

    end_time = time.time()
    epoch_time = end_time - start_time
    return epoch_time

def evaluate(model, test_loader, criterion, device):
    model.eval()
    test_loss = 0
    correct = 0
    total = 0
    start_time = time.time()

    with torch.no_grad():
        for batch_idx, (inputs, targets) in enumerate(test_loader):
            inputs, targets = inputs.to(device), targets.to(device)
            outputs = model(inputs)
            loss = criterion(outputs, targets)

            test_loss += loss.item()
            _, predicted = outputs.max(1)
            total += targets.size(0)
            correct += predicted.eq(targets).sum().item()

    end_time = time.time()
    test_time = end_time - start_time
    accuracy = 100. * correct / total
    return test_loss / len(test_loader), accuracy, test_time

gpu_train_times = []
gpu_test_times = []
gpu_accuracies = []

for epoch in range(num_epochs):
    print(f'Epoch {epoch+1}/{num_epochs}')
    train_time = train(model, train_loader, criterion, optimizer, device)
    test_loss, accuracy, test_time = evaluate(model, test_loader, criterion, device)
    
    gpu_train_times.append(train_time)
    gpu_test_times.append(test_time)
    gpu_accuracies.append(accuracy)
    
    print(f'Test Loss: {test_loss:.3f}, Accuracy: {accuracy:.2f}%, Time: {test_time:.2f}s')
    print('-----------------------------')

torch.save(model.state_dict(), 'resnet18_imagenet.pth')
print("Model saved successfully!")

model.eval()
model_fp32 = model
model_fp32.qconfig = torch.quantization.get_default_qconfig('fbgemm')
model_int8 = torch.quantization.quantize_dynamic(model_fp32, {nn.Linear}, dtype=torch.qint8)

torch.save(model_int8.state_dict(), 'resnet18_imagenet_quantized.pth')
print("Quantized model saved successfully!")

dummy_input = torch.randn(1, 3, 224, 224).to(device)
torch.onnx.export(model_int8, dummy_input, "resnet18_imagenet.onnx", export_params=True, opset_version=11)
print("ONNX model exported successfully!")

onnx_model = onnx.load("resnet18_imagenet.onnx")
tf_rep = prepare(onnx_model)
tf_rep.export_graph("resnet18_imagenet_tf")
print("TensorFlow model exported successfully!")

print("GPU Results:")
print(f"Average Training Time per Epoch: {sum(gpu_train_times)/len(gpu_train_times):.2f}s")
print(f"Average Inference Time: {sum(gpu_test_times)/len(gpu_test_times):.2f}s")
print(f"Final Accuracy: {gpu_accuracies[-1]:.2f}%")