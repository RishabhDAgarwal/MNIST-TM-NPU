# MNIST-TM-NPU
Synthesizable, area-optimized 2-Layer NPU (784-64-10) for Edge FPGAs. Features a time-multiplexed single-MAC architecture with cycle-accurate BRAM scheduling and robust fixed-point saturation logic.
Project Overview
This repository contains the Register Transfer Level (RTL) Verilog implementation of a custom Neural Processing Unit (NPU) tailored for resource-constrained Edge AI applications. The design executes a 2-layer Deep Neural Network (784 input, 64 hidden, 10 output) for MNIST digit classification.

Rather than deploying a highly parallelized, resource-heavy array of multipliers, this architecture achieves extreme area efficiency by heavily time-multiplexing a single Multiply-Accumulate (MAC) engine across two distinct computational phases.

Hardware Architecture & Key Features

Time-Multiplexed Datapath: Reuses a single custom MAC core for both Layer 1 and Layer 2 matrix multiplications, drastically minimizing DSP slice and LUT utilization on the FPGA fabric.

Phase-Driven Pipeline:

Phase 1: Reads from Image RAM and L1 Weights -> MAC -> 32-bit Hidden RAM.

Phase 2: Reads from Hidden RAM (with arithmetic right-shift >>> and 8-bit saturation) and L2 Weights -> MAC -> Output Registers.

Zero-Overhead Bias Injection: Eliminates the need for a dedicated bias adder circuit by pre-loading layer biases directly into the MAC accumulator during the clear_accum control signal.

Hardware-Safe Arithmetic: Implements strict bit-width management and custom saturation logic to prevent fixed-point overflow and wraparound, ensuring accurate ReLU activation and inference.

Cycle-Accurate Memory Interface: Designed with strict synchronization to account for the physical 1-cycle read latency of inferred synchronous Dual-Port BRAMs.

Fully Synthesizable: Written in standard, hardware-explicit Verilog (RTL) with no simulation-only constructs, ensuring immediate synthesizability for standard FPGA toolchains.
