#!/bin/bash

# Test runner script for wsl-utils

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Check if BATS is available
check_bats() {
    if ! command -v bats >/dev/null 2>&1; then
        echo -e "${RED}Error: BATS is not installed${NC}"
        echo "Please install BATS (Bash Automated Testing System)"
        echo "  Ubuntu/Debian: sudo apt install bats"
        echo "  macOS: brew install bats-core"
        echo "  Or clone from: https://github.com/bats-core/bats-core"
        exit 1
    fi
}

# Check dependencies
check_dependencies() {
    local missing_deps=()
    
    if ! command -v yq >/dev/null 2>&1; then
        missing_deps+=("yq")
    fi
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        echo -e "${YELLOW}Warning: Some dependencies are missing:${NC}"
        for dep in "${missing_deps[@]}"; do
            echo "  - $dep"
        done
        echo "Some tests may be skipped"
        echo
    fi
}

# Run specific test file
run_test_file() {
    local test_file="$1"
    echo -e "${BLUE}Running $(basename "$test_file")...${NC}"
    if bats "$test_file"; then
        echo -e "${GREEN}✓ $(basename "$test_file") passed${NC}"
        return 0
    else
        echo -e "${RED}✗ $(basename "$test_file") failed${NC}"
        return 1
    fi
}

# Main function
main() {
    local specific_test=""
    local verbose=false
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                echo "Usage: $0 [OPTIONS] [TEST_FILE]"
                echo ""
                echo "Options:"
                echo "  -h, --help     Show this help message"
                echo "  -v, --verbose  Verbose output"
                echo ""
                echo "Examples:"
                echo "  $0                           # Run all tests"
                echo "  $0 test_option_parsing.bats # Run specific test file"
                echo "  $0 -v                       # Run with verbose output"
                exit 0
                ;;
            -v|--verbose)
                verbose=true
                shift
                ;;
            *.bats)
                specific_test="$1"
                shift
                ;;
            *)
                echo -e "${RED}Error: Unknown option $1${NC}"
                exit 1
                ;;
        esac
    done
    
    echo -e "${BLUE}WSL-Utils Test Runner${NC}"
    echo "===================="
    echo
    
    # Change to project directory
    cd "$PROJECT_DIR"
    
    # Check prerequisites
    check_bats
    check_dependencies
    
    # Set up environment
    export BATS_TMPDIR="${TMPDIR:-/tmp}"
    
    local failed_tests=()
    local total_tests=0
    
    if [[ -n "$specific_test" ]]; then
        # Run specific test file
        if [[ ! -f "$SCRIPT_DIR/$specific_test" ]]; then
            echo -e "${RED}Error: Test file $specific_test not found${NC}"
            exit 1
        fi
        
        total_tests=1
        if ! run_test_file "$SCRIPT_DIR/$specific_test"; then
            failed_tests+=("$specific_test")
        fi
    else
        # Run all test files
        local test_files=()
        while IFS= read -r -d '' file; do
            test_files+=("$file")
        done < <(find "$SCRIPT_DIR" -name "test_*.bats" -print0 | sort -z)
        
        if [[ ${#test_files[@]} -eq 0 ]]; then
            echo -e "${YELLOW}No test files found${NC}"
            exit 0
        fi
        
        total_tests=${#test_files[@]}
        echo -e "${BLUE}Found $total_tests test files${NC}"
        echo
        
        for test_file in "${test_files[@]}"; do
            if ! run_test_file "$test_file"; then
                failed_tests+=("$(basename "$test_file")")
            fi
            echo
        done
    fi
    
    # Summary
    echo "===================="
    local passed_tests=$((total_tests - ${#failed_tests[@]}))
    echo -e "${BLUE}Test Summary:${NC}"
    echo -e "  ${GREEN}Passed: $passed_tests${NC}"
    echo -e "  ${RED}Failed: ${#failed_tests[@]}${NC}"
    echo -e "  Total:  $total_tests"
    
    if [[ ${#failed_tests[@]} -gt 0 ]]; then
        echo
        echo -e "${RED}Failed tests:${NC}"
        for test in "${failed_tests[@]}"; do
            echo -e "  ${RED}✗ $test${NC}"
        done
        exit 1
    else
        echo
        echo -e "${GREEN}All tests passed! 🎉${NC}"
        exit 0
    fi
}

main "$@"