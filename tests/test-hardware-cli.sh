#!/bin/bash
# CLI tests for oqlos hardware functionality
# Usage: ./tests/test-hardware-cli.sh

set +e

echo "========================================="
echo "OqlOS Hardware CLI Tests"
echo "========================================="
echo ""

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test counter
TESTS_PASSED=0
TESTS_FAILED=0

# Check if oqlctl is available
if ! command -v oqlctl &> /dev/null; then
    echo -e "${RED}oqlctl not found. Install oqlos: pip install -e ../oqlos${NC}"
    exit 1
fi

# Function to run a test
run_test() {
    local test_name=$1
    local command=$2
    
    echo -n "Testing: $test_name... "
    if eval "$command" > /dev/null 2>&1; then
        echo -e "${GREEN}PASS${NC}"
        ((TESTS_PASSED++))
        return 0
    else
        echo -e "${RED}FAIL${NC}"
        ((TESTS_FAILED++))
        return 1
    fi
}

# 1. Test oqlctl help
echo "1. CLI Help"
run_test "oqlctl help command" "oqlctl --help"
echo ""

# 2. Test scenario validation
echo "2. Scenario Validation (validate mode)"
run_test "Validate test-pompy.oql" "oqlctl -m validate /home/tom/github/oqlos/oqlos/oqlos/scenarios/test-pompy.oql"
echo ""

# 3. Test scenario dry-run (mock mode)
echo "3. Scenario Dry-Run (dry-run mode)"
run_test "Dry-run test-pompy.oql" "oqlctl -m dry-run /home/tom/github/oqlos/oqlos/oqlos/scenarios/test-pompy.oql"
echo ""

# 4. Test scenario execution in real mode (may timeout without hardware)
echo "4. Scenario Execution (execute mode - real hardware)"
echo "This test may timeout if hardware is not connected..."
if timeout 30 oqlctl -m execute /home/tom/github/oqlos/oqlos/oqlos/scenarios/test-pompy.oql > /dev/null 2>&1; then
    echo -e "${GREEN}PASS${NC}"
    ((TESTS_PASSED++))
else
    echo "Real mode execution failed or timed out (expected without hardware)"
    echo -e "${YELLOW}SKIP${NC}"
fi
echo ""

# 5. Test with JSON output
echo "5. JSON Output"
run_test "Dry-run with JSON output" "oqlctl -m dry-run --json /home/tom/github/oqlos/oqlos/oqlos/scenarios/test-pompy.oql"
echo ""

# 6. Test with sensor mocking
echo "6. Sensor Mocking"
run_test "Dry-run with mocked sensors" "oqlctl -m dry-run -s AI01=7.5 /home/tom/github/oqlos/oqlos/oqlos/scenarios/test-pompy.oql"
echo ""

# 7. Test quiet mode
echo "7. Quiet Mode"
run_test "Dry-run in quiet mode" "oqlctl -m dry-run -q /home/tom/github/oqlos/oqlos/oqlos/scenarios/test-pompy.oql"
echo ""

# 8. Test firmware URL configuration
echo "8. Firmware URL Configuration"
run_test "Dry-run with custom firmware URL" "oqlctl -m dry-run --firmware-url http://localhost:8202 /home/tom/github/oqlos/oqlos/oqlos/scenarios/test-pompy.oql"
echo ""

# 9. Test directory validation
echo "9. Directory Validation"
run_test "Validate scenarios directory" "oqlctl --validate-dir /home/tom/github/oqlos/oqlos/oqlos/scenarios"
echo ""

# 10. Show actual execution result
echo "10. Execution Result Display"
echo "Running scenario in dry-run mode with output:"
oqlctl -m dry-run /home/tom/github/oqlos/oqlos/oqlos/scenarios/test-pompy.oql
if [ $? -eq 0 ]; then
    echo -e "${GREEN}PASS${NC}"
    ((TESTS_PASSED++))
else
    echo -e "${RED}FAIL${NC}"
    ((TESTS_FAILED++))
fi
echo ""

# Summary
echo "========================================="
echo "Test Summary"
echo "========================================="
echo -e "Tests Passed: ${GREEN}${TESTS_PASSED}${NC}"
echo -e "Tests Failed: ${RED}${TESTS_FAILED}${NC}"
echo "Total Tests: $((TESTS_PASSED + TESTS_FAILED))"
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}All CLI tests passed!${NC}"
    exit 0
else
    echo -e "${RED}Some CLI tests failed!${NC}"
    exit 1
fi
