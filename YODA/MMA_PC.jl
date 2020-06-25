# Matrix Multiplication Accelerator (MMA)
# EEE4120F (HPES) 2020 YODA Project
# MMA Top Level Module (TLM)
# Contributors: Ian Grant [GRNIAN004], Liam Hyde [HYDLIA001], Jonah Swain [SWNJON003]

# === DEPENDENCIES ===
# To add packages to your Julia environment, type the following commands: using Pkg; Pkg.add("package name");
using SerialPorts;          # Serial port library (PySerial wrapper)
using Random;               # Random number generation library

# === FUNCTIONS ===
generate_matrix(M, N) = 100 .* rand(Float32, (M, N)); # Generates a random M x N single precision floating point (FP32) matrix

function transmit_matrix(port::SerialPort, matrix::Matrix, n) # Transmits a matrix to the MMA module over serial/UART
    read(port, bytesavailable(port)); # Discard waiting data
    write(port, UInt8(n)); # Send the matrix number (command to start receiving)
    M, N = size(matrix); # Get the matrix dimensions
    write(port, reinterpret(UInt8, [hton(UInt32(M))])); # Send the first dimension
    write(port, reinterpret(UInt8, [hton(UInt32(M))])); # Send the second dimension
    for i ∈ 1:M
        for j ∈ 1:N
            e = reinterpret(UInt8, [hton(matrix[i, j])]);
            write(port, e);
        end;
    end;
    while (bytesavailable(port) == 0) end; # Wait for ACK
end;

function get_matrix(port::SerialPort) # Gets the result matrix from the MMA
    read(port, bytesavailable(port)); # Discard waiting data
    write(port, UInt8(4)); # Send the command to transmit result
    while(bytesavailable(port) < 8) end; # Wait for data
    M = reinterpret(UInt32, Vector{UInt8}(read(port, 4)[4:-1:1]))[1]; # Get first dimension
    N = reinterpret(UInt32, Vector{UInt8}(read(port, 4)[4:-1:1]))[1]; # Get second dimension
    matrix = zeros(Float32, (M, N)); # Initialise matrix
    for i ∈ 1:M
        for j ∈ 1:N
            while (bytesavailable(port) < 4) end; # Wait for data
            v = Vector{UInt8}(read(port, 4));
            matrix[i, j] = ntoh(reinterpret(Float32, v)[1]); # Populate matrix
        end;
    end;
    matrix # Return matrix
end;

function start_mma(port::SerialPort) # Sends the start command to the MMA module
    read(port, bytesavailable(port)); # Discard waiting data
    write(port, UInt8(3));
end;

function compare_matrices(A::Matrix, B::Matrix) # Compares two matrices
    if (size(A) != size(B)) return false; end; # Return false if dimensions unequal
    M, N = size(A);
    for i in 1:M
        for j in 1:N
            if (abs(A[i, j] - B[i, j]) > 0.0001) return false; end; # Return false if any element not within tolerance
        end;
    end;
    true # Return true
end;

function multiply_matrices(A::Matrix, B::Matrix) # Multiply two matrices
    A_M, A_N = size(A); # Get dimensions of matrix A
    B_M, B_N = size(B); # Get dimensions of matrix B
    if (A_N != B_M) # Check if dimensions are compatible for multiplication
        throw(ErrorException("Matrix dimensions incompatible for multiplication"));
    end;
    R_M, R_N = A_M, B_N; # Calculate dimensions of result
    R = zeros(Float32, (R_M, R_N)); # Initialise result matrix
    for i ∈ 1:R_M
        for j ∈ 1:R_N
            for k ∈ 1:A_N
                R[i, j] += A[i, k] * B[k, j]; # Do multiplication stuff
            end;
        end;
    end;
    R # Return R
end;

function test_mma() # Tests the MMA module
    # Test parameters
    A_M = 2;
    A_N = 2;
    B_M = 2;
    B_N = 2;

    # Open serial port
    println("Opening serial port");
    sp = SerialPort("COM7", 9600);

    # Generate matrices
    println("Generating matrices");
    #A = generate_matrix(A_M, A_N);
    #B = generate_matrix(B_M, B_N);
    A = Float32.([1.0 2.0; 3.0 4.0]);
    B = Float32.([5.0 6.0; 7.0 8.0]);

    transfer_time = 0.0;

    # Transmit matrices to MMA
    println("Transmitting matrix A");
    transfer_time += @elapsed transmit_matrix(sp, A, 1); # Transmit matrix A

    println("Transmitting matrix B");
    transfer_time += @elapsed transmit_matrix(sp, B, 2); # Transmit matrix B

    # Multiply matrices on MMA
    println("Sending start command");
    start_mma(sp); # Send start command
    println("Waiting for DONE response");
    while (bytesavailable(sp) == 0) end; # Wait for DONE

    # Get result from MMA
    println("Retrieving result from MMA");
    Rtemp_mma = @timed get_matrix(sp);
    R_mma = Rtemp_mma[1];
    transfer_time += Rtemp_mma[2];

    # Compute golden measure
    Rtemp_pc = @timed multiply_matrices(A, B);
    R_pc = Rtemp_pc[1];
    pc_time = Rtemp_pc[2];

    # Display results
    println("");
    if (compare_matrices(R_pc, R_mma))
        println("MMA and golden measure results match");
    else
        println("MMA and golden measure results do not match");
    end
    println("Golden measure time: ", pc_time, "s   MMA transfer time: ", transfer_time, "s");

    close(sp); # Close serial port
end;

# mma_cycles(A_M, A_N, B_N) = 9 + A_M*(1 + B_N*(1 + 26*A_N));

# function generate_results()
#     # Pre-compile functions
#     A = generate_matrix(2, 2);
#     B = generate_matrix(2, 2);
#     @timed multiply_matrices(A, B); 

#     println("size, time (PC), transfer time, multiplication time")

#     for d ∈ 5:5:200
#         A = generate_matrix(d, d);
#         B = generate_matrix(d, d);
#         pcr = @timed multiply_matrices(A, B);
#         ttime = 3*((1+(d*d+2)*4)*11/9600);
#         mtime = mma_cycles(d, d, d)/100000000;
#         println(d, ", ", pcr[2], ", ", ttime, ", ", mtime);
#     end;
# end;

# === MAIN CODE BODY ===
test_mma();