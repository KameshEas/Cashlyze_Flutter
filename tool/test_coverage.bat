@echo off
REM Test Coverage Script for Windows
REM This script runs all tests and generates an HTML coverage report

echo ========================================
echo Running Flutter Tests with Coverage
echo ========================================

REM Clean previous coverage data
if exist coverage rmdir /s /q coverage

REM Run tests with coverage
echo.
echo Running tests...
call flutter test --coverage

if %errorlevel% neq 0 (
    echo.
    echo ERROR: Tests failed!
    exit /b %errorlevel%
)

REM Check if lcov is installed
where genhtml >nul 2>nul
if %errorlevel% neq 0 (
    echo.
    echo WARNING: genhtml not found. Install lcov to generate HTML reports.
    echo Install via Chocolatey: choco install lcov
    echo.
    echo Coverage data saved to: coverage/lcov.info
    exit /b 0
)

REM Generate HTML report
echo.
echo Generating HTML coverage report...
call genhtml coverage/lcov.info -o coverage/html

if %errorlevel% neq 0 (
    echo.
    echo ERROR: Failed to generate HTML report
    exit /b %errorlevel%
)

echo.
echo ========================================
echo Coverage Report Generated Successfully!
echo ========================================
echo.
echo Report location: coverage/html/index.html
echo.
echo Opening report in browser...
start coverage/html/index.html

exit /b 0
