#!/bin/bash

# PlaceAlertMe - Parallel Test Runner
# Runs C++, Android, and iOS tests simultaneously
# Usage: ./run_all_tests.sh [c++|android|ios|all]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPORT_DIR="$SCRIPT_DIR/test-results"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Create results directory
mkdir -p "$REPORT_DIR"

# Function to print colored output
print_header() {
    echo -e "\n${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}\n"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_info() {
    echo -e "${YELLOW}ℹ $1${NC}"
}

# Function to run C++ tests
run_cpp_tests() {
    print_header "Running C++ Core Engine Tests"

    if ! command -v gtest &> /dev/null; then
        print_error "Google Test not found. Install with: sudo apt-get install libgtest-dev"
        return 1
    fi

    cd "$SCRIPT_DIR/cpp/geo_engine/tests"

    if [ ! -d "build" ]; then
        print_info "Building C++ tests..."
        mkdir -p build
        cd build
        cmake ..
        make
        cd ..
    else
        cd build
        make
        cd ..
    fi

    print_info "Running tests..."
    ./build/geo_engine_test --gtest_output=xml:"$REPORT_DIR/cpp-test-results.xml"

    if [ $? -eq 0 ]; then
        print_success "C++ tests passed"
        return 0
    else
        print_error "C++ tests failed"
        return 1
    fi
}

# Function to run Android tests
run_android_tests() {
    print_header "Running Android Tests"

    if ! command -v gradle &> /dev/null; then
        if [ ! -f "$SCRIPT_DIR/android/gradlew" ]; then
            print_error "Gradle not found"
            return 1
        fi
    fi

    cd "$SCRIPT_DIR/android"

    print_info "Running unit tests..."
    ./gradlew test --scan > "$REPORT_DIR/android-unit-test.log" 2>&1
    UNIT_RESULT=$?

    if [ $UNIT_RESULT -eq 0 ]; then
        print_success "Android unit tests passed"
    else
        print_error "Android unit tests failed"
        cat "$REPORT_DIR/android-unit-test.log"
        return 1
    fi

    return 0
}

# Function to run iOS tests
run_ios_tests() {
    print_header "Running iOS Tests"

    if ! command -v xcodebuild &> /dev/null; then
        print_error "Xcode not found. macOS only."
        return 1
    fi

    cd "$SCRIPT_DIR/ios"

    print_info "Running tests..."
    xcodebuild test \
        -scheme PlaceAlertMe \
        -enableCodeCoverage YES \
        -resultBundlePath "$REPORT_DIR/ios-test-results.xcresult" \
        > "$REPORT_DIR/ios-test.log" 2>&1

    if [ $? -eq 0 ]; then
        print_success "iOS tests passed"
        return 0
    else
        print_error "iOS tests failed"
        cat "$REPORT_DIR/ios-test.log"
        return 1
    fi
}

# Function to run all tests in parallel
run_all_parallel() {
    print_header "Running All Tests in Parallel"

    print_info "Starting C++ tests..."
    run_cpp_tests > "$REPORT_DIR/cpp.log" 2>&1 &
    CPP_PID=$!

    print_info "Starting Android tests..."
    run_android_tests > "$REPORT_DIR/android.log" 2>&1 &
    ANDROID_PID=$!

    print_info "Starting iOS tests..."
    if [[ "$OSTYPE" == "darwin"* ]]; then
        run_ios_tests > "$REPORT_DIR/ios.log" 2>&1 &
        IOS_PID=$!
    else
        print_info "Skipping iOS tests (macOS only)"
    fi

    # Wait for all tests to complete
    echo -e "\n${YELLOW}Waiting for tests to complete...${NC}\n"

    CPP_PASSED=0
    ANDROID_PASSED=0
    IOS_PASSED=0

    # Wait for C++ tests
    if wait $CPP_PID; then
        CPP_PASSED=1
        print_success "C++ tests completed"
    else
        print_error "C++ tests failed"
        tail -20 "$REPORT_DIR/cpp.log"
    fi

    # Wait for Android tests
    if wait $ANDROID_PID; then
        ANDROID_PASSED=1
        print_success "Android tests completed"
    else
        print_error "Android tests failed"
        tail -20 "$REPORT_DIR/android.log"
    fi

    # Wait for iOS tests if started
    if [[ "$OSTYPE" == "darwin"* ]] && [ ! -z "$IOS_PID" ]; then
        if wait $IOS_PID; then
            IOS_PASSED=1
            print_success "iOS tests completed"
        else
            print_error "iOS tests failed"
            tail -20 "$REPORT_DIR/ios.log"
        fi
    fi

    # Print summary
    print_header "Test Summary"

    total=0
    passed=0

    echo "C++ Core Engine: " -n
    if [ $CPP_PASSED -eq 1 ]; then
        echo -e "${GREEN}PASSED${NC}"
        ((passed++))
    else
        echo -e "${RED}FAILED${NC}"
    fi
    ((total++))

    echo "Android: " -n
    if [ $ANDROID_PASSED -eq 1 ]; then
        echo -e "${GREEN}PASSED${NC}"
        ((passed++))
    else
        echo -e "${RED}FAILED${NC}"
    fi
    ((total++))

    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo "iOS: " -n
        if [ $IOS_PASSED -eq 1 ]; then
            echo -e "${GREEN}PASSED${NC}"
            ((passed++))
        else
            echo -e "${RED}FAILED${NC}"
        fi
        ((total++))
    fi

    echo -e "\n${BLUE}Results: $passed/$total test suites passed${NC}"

    if [ $passed -eq $total ]; then
        print_success "All tests passed!"
        return 0
    else
        print_error "Some tests failed. Check $REPORT_DIR for details."
        return 1
    fi
}

# Main script logic
PLATFORM="${1:-all}"

case "$PLATFORM" in
    c++)
        run_cpp_tests
        ;;
    android)
        run_android_tests
        ;;
    ios)
        if [[ "$OSTYPE" != "darwin"* ]]; then
            print_error "iOS tests require macOS"
            exit 1
        fi
        run_ios_tests
        ;;
    all)
        run_all_parallel
        ;;
    help)
        echo "Usage: $0 [c++|android|ios|all|help]"
        echo ""
        echo "Options:"
        echo "  c++      Run C++ core engine tests only"
        echo "  android  Run Android tests only"
        echo "  ios      Run iOS tests only"
        echo "  all      Run all tests in parallel (default)"
        echo "  help     Show this help message"
        echo ""
        echo "Test results are saved to: $REPORT_DIR"
        exit 0
        ;;
    *)
        print_error "Unknown platform: $PLATFORM"
        echo "Usage: $0 [c++|android|ios|all|help]"
        exit 1
        ;;
esac

exit $?
