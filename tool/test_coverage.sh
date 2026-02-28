#!/bin/bash
# Test Coverage Script for macOS/Linux
# This script runs all tests and generates an HTML coverage report

set -e

echo "========================================"
echo "Running Flutter Tests with Coverage"
echo "========================================"

# Clean previous coverage data
rm -rf coverage

# Run tests with coverage
echo ""
echo "Running tests..."
flutter test --coverage

# Check if genhtml is installed
if ! command -v genhtml &> /dev/null; then
    echo ""
    echo "WARNING: genhtml not found. Install lcov to generate HTML reports."
    echo "  macOS: brew install lcov"
    echo "  Linux: sudo apt-get install lcov"
    echo ""
    echo "Coverage data saved to: coverage/lcov.info"
    exit 0
fi

# Generate HTML report
echo ""
echo "Generating HTML coverage report..."
genhtml coverage/lcov.info -o coverage/html

echo ""
echo "========================================"
echo "Coverage Report Generated Successfully!"
echo "========================================"
echo ""
echo "Report location: coverage/html/index.html"
echo ""

# Open report in browser
if [[ "$OSTYPE" == "darwin"* ]]; then
    echo "Opening report in browser..."
    open coverage/html/index.html
elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
    echo "Opening report in browser..."
    xdg-open coverage/html/index.html
else
    echo "Please open coverage/html/index.html in your browser"
fi

exit 0
