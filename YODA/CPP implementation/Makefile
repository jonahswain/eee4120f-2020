# EEE4120F (HPES) YODA Project C++ implementation
# Makefile
# Jonah Swain [SWNJON003]

TARGET_EXEC = mma # Project output


CPPC = g++ # Compiler

# Directories
SRCDIR = src# Source (.cpp) directory
HDIR = include# Include/header (.h) directory
OBJDIR = obj# Compiled object (.o) directory

.SUFFIXES: .h .cpp .o # File extensions/suffixes
.PHONY: clean test # Phony rules (rules without dependencies)

SOURCES = main.cpp
OBJECTS = $(SOURCES:%.cpp=$(OBJDIR)/%.o) # Generated list of object files

INCLFLAGS = -I$(HDIR) # Include flags
CPPFLAGS = $(INCLFLAGS) -std=c++17 # Compiler flags

# Target executable rule
$(TARGET_EXEC): $(OBJECTS)
	$(CPPC) $(OBJECTS) -o $@

# C++ Compilation rule
$(OBJDIR)/%.o: $(SRCDIR)/%.cpp
	$(CPPC) $(CPPFLAGS) -c $< -o $@

# Clean
clean:
	rm -rf $(OBJDIR)/*
	rm $(TARGET_EXEC)