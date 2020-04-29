/*
 EEE4120F (HPES) YODA Project C++ implementation
 MemoryController.h - Memory controller declarations
 Jonah Swain [SWNJON003]
*/

/* INCLUDE GUARD */
#ifndef MEMORYCONTROLLER_H
#define MEMORYCONTROLLER_H

/* DEPENDENCIES */


/* PROJECT NAMESPACE (CLASS AND FUNCTION DECLARATIONS) */
namespace mma {
    class MemoryController {
        private:
            unsigned int memSize; // Size of memory block (in bytes)
            unsigned short* memBlock; // Memory block

        public:
            MemoryController(unsigned int size); // Constructor
            ~MemoryController(); // Destructor

            unsigned short read(unsigned int addr); // Read data
            void write(unsigned int addr, unsigned short data); // Write data
    };
}

#endif