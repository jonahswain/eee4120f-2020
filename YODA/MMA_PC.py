# Matrix Multiplication Accelerator (MMA)
# EEE4120F (HPES) 2020 YODA Project
# PC-side python program
# Authors: Ian Grant [GRNIAN004], Liam Hyde [HYDLIA001], Jonah Swain [SWNJON003]

# === DEPENDENCIES ===
import random
import serial
import struct

# === FUNCTIONS ===

# Generates a random MxN single-precision floating point (FP32) matrix
def generateMatrix(M,N):
    Matrix = [[0]*N]*M
    for i in range(M):
        templist = [0]*N
        for j in range(N):
            templist[j] = random.uniform(0,100)
            Matrix[i] = templist 
    return Matrix

# Opens a serial port
def openSerialPort(baud, port):
    ser = serial.Serial()
    ser.baudrate = baud
    ser.port = port
    ser.open()
    return ser
    
# Transmits a matrix to the MMA over serial
def transmitMatrix(ser, matrix, num):
    if(ser.is_open):

        ser.write((num & 0b11111111)) # Send the matrix number (1 or 2)

        M = len(matrix)
        N = len(matrix[0])

        M_list = bytearray(struct.pack(">I", M))
        N_list = bytearray(struct.pack(">I", N))

        for i in M_list: # Send dimension 1 (M) (as 4 bytes UInt, one byte at a time, big-endian)
            ser.write(i)
        for i in N_list: # Send dimension 2 (N) (as 4 bytes UInt, one byte at a time, big-endian)
            ser.write(i)

        for i in range(0,M):
            for j in range(0,N):
                value = bytearray(struct.pack(">f", matrix[i][j]))
                for k in value:
                    ser.write(k)
        
        while (ser.in_waiting > 0): # Wait for ACK (0x06) from the MMA, or timeout
            pass

        ACK = ser.read(1)
        if ACK != 6:
            print("Error: non-ACK reply.")
        else:
            print("Matrix " + num + "successfuly transmitted")

    else:
        print("Serial not open.")

def startMMA(ser): # Sends the start multiplying command
    ser.write(0x03)

def checkCompatiblity(A,B):
    A = A
    B = B
    if len(A) == len(B) and len(A[0]) == len(B[0]):
        print("square")
        return 1
    elif len(A) == len(B) and len(A[0]) < len(B[0]):
        print("Horizontal rectangle")
        return 2 
    elif len(A) > len(B) and len(A[0]) == len(B[0]):
        print("Veritcal rectangle")
        return 3         
    elif len(A) < len(B) and len(A[0]) > len(B[0]):
        print("Shrunk Square")
        return 4  
    elif len(A) > len(B) and len(A[0]) < len(B[0]):
        print("Grown Square")
        return 5
    elif len(A) == len(B[0]):
        print("Yeet, it works")
        return 6
    else:
        print("incompatible matrices, or is not a basic case and result may be wrong")
        return 0

def multiplyMatrices(A, B): # Multiplies A and B
    compatibleFlag = 0
    X = A
    Y = B
    compatibleFlag = checkCompatiblity(A, B)
    outputMatrix = None
    if compatibleFlag != 0: 
        M = len(A)
        N = len(A[0])
        outputMatrix = [[0]*N]*M
        #print(outputMatrix)
        outputMatrix = [[sum(a*b for a,b in zip(X_row,Y_col)) for Y_col in zip(*Y)] for X_row in X] 
        print(outputMatrix) 
    if compatibleFlag == 0: 
        M = len(A)
        N = len(A[0])
        outputMatrix = [[0]*N]*M
        #print(outputMatrix)
        outputMatrix = [[sum(a*b for a,b in zip(X_row,Y_col)) for Y_col in zip(*Y)] for X_row in X] 
        print(outputMatrix)
    return outputMatrix

# Gets the result from the MMA (transmitted in similar form to transmitMatrix in reverse direction)
def getMatrix(ser):

    ser.write(0x04)
    M = ser.read(4)
    N = ser.read(4)
    result = [[None]*N]*M
    for i in range(0,M):
        for j in range(0,N):
            result[i][j] = ser.read(4)
    return result


def compareMatrices(A, B):
    finishedFlag = 0
    for i in range(len(A)):
        for j in range(len(A[0])):
            if A[i][j] == B[i][j]:
                continue              
            else:
                print("false")
                return False
        finishedFlag += 1 
        if finishedFlag == len(A):
            print("true")
            return True
        else:
            continue

# === MAIN FUNCTION ===
def main():
    random.seed(None)
    print("MMA: multiply 2 MxN matricies")
    
    A = generateMatrix(2,2)
    B = generateMatrix(2,2)
    
    print(A)
    print(B)

    ser = openSerialPort(9600, 'COM7')
    transmitMatrix(ser, A, 1)
    transmitMatrix(ser, B, 2)
    startMMA(ser)
    R_golden = multiplyMatrices(A, B)
    while (ser.read() != 0x05):
        pass
    R_mma = getMatrix(ser)
    comp = compareMatrices(R_golden, R_mma)
    print(comp)

    ser.close()

# === EXECUTE MAIN ===
if __name__ == '__main__':
    main()
