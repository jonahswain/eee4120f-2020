/*
 EEE4120F (HPES) YODA Project C++ implementation
 MemoryController.cpp - Memory controller implementation
 Jonah Swain [SWNJON003]
*/

/* HEADER INCLUDE */
#include "MemoryController.h"

/* FUNCTION IMPLEMENTATION */

mma::MemoryController::MemoryController(unsigned int size){ // Constructor
    memSize = size;
    memBlock = new unsigned short[memSize];
}

mma::MemoryController::~MemoryController(){ // Destructor
    memSize = 0;
    delete [] memBlock;
}

unsigned short mma::MemoryController::read(unsigned int addr){ // Read data
    if (addr < memSize){
        return memBlock[addr];
    }
}

void mma::MemoryController::write(unsigned int addr, unsigned short data){ // Write data
    if (addr < memSize){
        memBlock[addr] = data;
    }
}
