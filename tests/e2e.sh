#!/bin/bash
# E2E tests for WebOQL service using curl
# Usage: ./tests/e2e.sh

set +e  # Don't exit on error, we want to count failures

WEB_URL="http://localhost:8203"
API_BASE="${WEB_URL}/api/v1/editor"

echo "========================================="
echo "WebOQL E2E Tests"
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

# 1. Health check
echo "1. Health Check"
run_test "WebOQL service is running" "curl -sf ${WEB_URL}"
echo ""

# 2. Health endpoint
echo "2. Health Endpoint"
run_test "Health endpoint" "curl -sf ${WEB_URL}/health"
echo ""

# 3. System status
echo "3. System Status"
run_test "System status endpoint" "curl -sf ${API_BASE}/status"
if curl -sf ${API_BASE}/status > /dev/null 2>&1; then
    echo "Status response:"
    curl -s ${API_BASE}/status | python3 -m json.tool
fi
echo ""

# 4. File listing
echo "4. File Listing"
run_test "File listing endpoint" "curl -sf ${API_BASE}/files"
if curl -sf ${API_BASE}/files > /dev/null 2>&1; then
    FILE_COUNT=$(curl -s ${API_BASE}/files | python3 -c "import sys, json; print(len(json.load(sys.stdin)['files']))" 2>/dev/null || echo "0")
    echo "Found ${FILE_COUNT} scenario files"
fi
echo ""

# 5. File reading
echo "5. File Reading"
run_test "Read test-pompy.oql" "curl -sf ${API_BASE}/file/test-pompy.oql"
echo ""

# 6. Scenario execution (mock mode)
echo "6. Scenario Execution (Mock Mode)"
EXECUTION_ID="e2e-test-$(date +%s)"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%S.%3NZ")
run_test "Execute scenario in mock mode" "curl -sf -X POST ${API_BASE}/execute -H 'Content-Type: application/json' -d '{\"scenario_file\": \"test-pompy.oql\", \"mode\": \"mock\", \"speed\": 1.0, \"execution_id\": \"${EXECUTION_ID}\", \"timestamp\": \"${TIMESTAMP}\"}'"
echo ""

# 7. URL parameters
echo "7. URL Parameters"
run_test "URL parameters with file, mode, speed" "curl -sf '${WEB_URL}/?file=test-pompy.oql&mode=mock&speed=1.0'"
echo ""

# 8. Hardware availability check
echo "8. Hardware Availability"
if curl -sf ${API_BASE}/status > /dev/null 2>&1; then
    STATUS=$(curl -s ${API_BASE}/status)
    PIADC_AVAILABLE=$(echo $STATUS | python3 -c "import sys, json; print(json.load(sys.stdin).get('piadc_available', False))" 2>/dev/null || echo "False")
    MOTOR_AVAILABLE=$(echo $STATUS | python3 -c "import sys, json; print(json.load(sys.stdin).get('motor_available', False))" 2>/dev/null || echo "False")
    MODBUS_AVAILABLE=$(echo $STATUS | python3 -c "import sys, json; print(json.load(sys.stdin).get('modbus_available', False))" 2>/dev/null || echo "False")

    echo "PIADC Available: $([ "$PIADC_AVAILABLE" = "True" ] && echo -e "${GREEN}Yes${NC}" || echo -e "${RED}No${NC}")"
    echo "Motor Available: $([ "$MOTOR_AVAILABLE" = "True" ] && echo -e "${GREEN}Yes${NC}" || echo -e "${RED}No${NC}")"
    echo "Modbus Available: $([ "$MODBUS_AVAILABLE" = "True" ] && echo -e "${GREEN}Yes${NC}" || echo -e "${RED}No${NC}")"
else
    echo -e "${RED}Cannot check hardware availability - status endpoint failed${NC}"
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
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}Some tests failed!${NC}"
    exit 1
fi
