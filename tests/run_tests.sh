#!/bin/bash

# Test runner script for Ada List Scheduling
# This script can be run from the tests/ directory

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo "=========================================="
echo "  Ada List Scheduling Test Runner"
echo "=========================================="
echo ""

# Check if gnatmake is available
if ! command -v gnatmake &> /dev/null; then
    echo "ERROR: gnatmake (GNAT Ada compiler) is not installed."
    echo "Please install GNAT Ada compiler to run tests."
    exit 1
fi

# Navigate to project root
cd "$PROJECT_ROOT"

# Check if we're in the right directory
if [ ! -f "list_scheduling.gpr" ]; then
    echo "ERROR: Not in the project root directory."
    echo "Project root: $PROJECT_ROOT"
    exit 1
fi

# Create object directory if it doesn't exist
mkdir -p obj

# Clean previous builds
echo "Cleaning previous builds..."
rm -rf obj/*.o obj/*.ali

# Compile the project
echo "Compiling List_Scheduling library..."
gnatmake -P list_scheduling.gpr 2>&1 | grep -v "^  " | grep -v "^$"

if [ $? -ne 0 ]; then
    echo "ERROR: Compilation failed."
    exit 1
fi

echo ""
echo "Compiling test suite..."
cd tests
gnatmake -P ../list_scheduling.gpr test_list_scheduling.adb 2>&1 | grep -v "^  " | grep -v "^$"

if [ $? -ne 0 ]; then
    echo "ERROR: Test compilation failed."
    exit 1
fi

echo ""
echo "Running tests..."
echo "=========================================="
./test_list_scheduling

# Clean up
# rm -f test_list_scheduling
# rm -f ../obj/*.o ../obj/*.ali

echo ""
echo "Test run complete."
