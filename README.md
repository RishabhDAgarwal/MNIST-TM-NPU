# MNIST-TM-NPU 

**Synthesizable, area-optimized 2-Layer Neural Processing Unit (784-64-10) for Edge FPGAs.**

## 1. Abstract
This repository contains the complete RTL (Verilog) and software (Python) pipeline for a custom Deep Neural Network accelerator. Designed from scratch for edge deployment, this Application-Specific Integrated Circuit (ASIC) classifies handwritten digits from the MNIST dataset. Instead of unrolling the neural network and consuming thousands of DSP slices, this architecture uses a **Time-Multiplexed Single-MAC** engine to compute the entire network sequentially, heavily prioritizing silicon area optimization. 

It features 64-bit overflow-safe accumulation, hardware ArgMax, and cycle-accurate BRAM scheduling, verified mathematically against a custom Python Digital Twin.


## 2. Introduction & Objective
With the rise of Edge AI, deploying neural networks on dedicated hardware accelerators (FPGAs/ASICs) provides massive latency and power advantages over standard CPUs. 

The objective of this project was to design a custom Finite State Machine (FSM) and datapath capable of processing a 784-64-10 neural network entirely in hardware. The scope spans the entire AI-to-Silicon pipeline: training the model in software, quantizing the floating-point weights to integers, engineering the Verilog datapath, and verifying the hardware execution using Xilinx Vivado.


## 3. Software Architecture & Model Training
The model is a Multi-Layer Perceptron (MLP) built in TensorFlow/Keras:
* **Input Layer:** 784 pixels (28x28 images)
* **Hidden Layer:** 64 Neurons (ReLU activation)
* **Output Layer:** 10 Neurons (Digits 0-9)

### Post-Training Quantization (PTQ) & Compound Scaling
Floating-point math is too expensive for edge FPGAs. The Python script scales the model parameters into 8-bit integers. However, simple independent quantization destroys accuracy. 

To bridge the software-hardware gap, the Python extraction script calculates **Compounded Scale Factors**. Because Phase 1 multiplies an 8-bit pixel by an 8-bit weight, the resulting MAC product scales massively. The 32-bit hardware biases are dynamically scaled using a compound factor (Pixel Scale × Weight Scale) to ensure they are not mathematically erased by the massive products during accumulation.

## 4. Hardware Architecture (The Verilog Datapath)
The RTL codebase is designed to squeeze the maximum mathematical throughput out of the smallest possible silicon footprint.

| Component | Bit-Width / Spec |
| :--- | :--- |
| **Input Pixels** | 8-bit (Unsigned) |
| **Weights** | 8-bit (Two's Complement) |
| **Biases** | 32-bit (Two's Complement) |
| **MAC Accumulator** | 64-bit (Signed) |
| **Hidden Layer RAM** | 64 words × 64-bit |

* **The Multiply-Accumulate (MAC) Engine:** Features an upgraded 52-bit product and a 64-bit accumulator to prevent integer overflow during high-density feature extraction.
* **Memory Management:** The 8-bit weights and 32-bit biases are stored in Read-Only Memory (ROM). A dedicated `hidden_layer_ram` acts as the bridge, storing Phase 1's 64-bit outputs to be seamlessly fetched as Phase 2's inputs.
* **Hardware ArgMax:** Bypasses expensive Softmax logic. Uses a lightweight, native 64-bit hardware comparator to determine the winning digit on the fly, saving thousands of logic cells with zero accuracy loss.


## 5. The Finite State Machine (Control Logic)
The `neural_net_top` orchestrates the inference using a dual-phase, 10-state FSM:

* **Phase 1: Input to Hidden Layer (784 -> 64)**
  The FSM sweeps through all 784 pixels for a single hidden neuron. Pixels and weights are routed into the MAC, passed through a combinational hardware ReLU, and saved to the internal RAM. This repeats 64 times.
* **Phase 2: Hidden to Output Layer (64 -> 10)**
  The FSM switches the routing MUXes (`is_phase_2 = 1`). The MAC reads the 64-bit intermediate features from RAM, multiplies them by the Phase 2 output weights, and feeds the results directly into the ArgMax classifier.

## 6. Engineering Challenges & Hardware Debugging
This project required solving several critical software-to-silicon interfacing bugs:

### 1. The Directory Trap 
* **The Bug:** Vivado was loading red `XX` values into memory because it was looking for the `.hex` files inside a deep, temporary `xsim` cache folder instead of the main project folder.
* **The Fix:** Bypassed the Vivado GUI completely, went into the Verilog code, and hardcoded Absolute Paths using forward slashes (e.g., `C:/Users/.../test_image.hex`). Forced a "Reset Simulation Run" to nuke the cache and correctly link the files.

### 2. The 64-bit Upgrade
* **The Bug:** To improve accuracy, quantization was stripped out and the MAC was bumped to 64 bits. This caused catastrophic Synthesis errors (`illegal operand for operator ?:`) because the architecture was trying to force 64-bit wires into legacy 16-bit and 48-bit ports.
* **The Fix:** Upgraded the entire motherboard. Widened the `hidden_layer_data`, updated all routing MUXes, and upgraded the ReLU and ArgMax peripheral chips to handle the massive 64-bit highway.

### 3. Scale Factor Asymmetry 
* **The Bug:** The FPGA was doing perfect math but predicting the wrong digits (e.g., predicting 0 instead of 3). The Python script had quantized the weights and biases independently. The MAC product was massive, and the independently scaled bias was too small, effectively deleting the biases from the network.
* **The Fix:** Rewrote the Python extraction script to use a Compounded Scale Factor. Multiplied the Phase 1 and Phase 2 scales together and upgraded the biases to massive 32-bit numbers so the hardware math matched the software perfectly.

### 4. The 32-bit Sign-Extension Bug 
* **The Bug:** After upgrading the biases to 32 bits, massive negative numbers were losing their minus signs when plugged into the 64-bit MAC. A score of `-100,000` was magically turning into `+4.29 Billion`, causing the ArgMax module to declare the wrong winner.
* **The Fix:** Manually built a Sign-Extension MUX: `{{32{bias[31]}}}`. This grabbed the true sign bit and padded it out to 64 bits, allowing the MAC to understand and safely accumulate negative numbers again.

## 7. Repository Structure

```text
├── sources/
│   ├── new/
│   │   ├── neural_net_top.v       # Top-level motherboard and Datapath MUXes
│   │   ├── mac_unit.v             # Single Multiply-Accumulate Engine
│   │   ├── argmax.v               # Hardware classifier
│   │   ├── relu_activation.v      # Combinational ReLU logic
│   │   ├── hidden_layer_ram.v     # Phase 1 -> Phase 2 feature memory
│   │   └── *rom.v                 # Memory primitives for Weights/Biases/Images
│   ├── python/
│   │   └── train_and_extract.py   # TF/Keras training & 32-bit Hex extraction script
├── data/
│   ├── test_image.hex
│   ├── hidden_weights.hex
│   ├── hidden_biases.hex
│   ├── output_weights.hex
|   ├──output_biases.hex
└── README.md
|── tb_neural_net.v                 # testbench
