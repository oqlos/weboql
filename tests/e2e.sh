#!/bin/bash
# E2E tests for WebOQL service using curl
# Usage: ./tests/e2e.sh

set +e  # Don't exit on error, we want to count failures

WEB_URL_CANDIDATE="${WEB_URL:-http://localhost:8203}"
WEB_URL=""
API_BASE=""
MOTOR_URL="${MOTOR_URL:-http://localhost:49055}"
MOTOR_URL_EFFECTIVE=""

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

check_weboql_health() {
    local response
    local service

    response=$(curl -sf "${WEB_URL}/health" 2>/dev/null)
    if [ $? -ne 0 ]; then
        return 1
    fi

    service=$(printf '%s' "$response" | python3 -c '
import json
import sys

try:
    data = json.load(sys.stdin)
except Exception:
    raise SystemExit(1)

print(data.get("service", ""))
' 2>/dev/null)

    [ "$service" = "weboql" ]
}

resolve_weboql_url() {
    local candidate

    for candidate in "$WEB_URL_CANDIDATE" "http://localhost:8210" "http://localhost:8203" "http://localhost:8101" "http://localhost:8000"; do
        [ -n "$candidate" ] || continue

        if ! check_weboql_health_for "$candidate"; then
            continue
        fi

        if ! curl -sf "$candidate/editor" > /dev/null 2>&1; then
            continue
        fi

        WEB_URL="$candidate"
        API_BASE="${WEB_URL}/api/v1/editor"
        return 0
    done

    WEB_URL="$WEB_URL_CANDIDATE"
    API_BASE="${WEB_URL}/api/v1/editor"
    return 1
}

check_weboql_health_for() {
    local candidate=$1
    local response
    local service

    response=$(curl -sf "${candidate}/health" 2>/dev/null)
    if [ $? -ne 0 ]; then
        return 1
    fi

    service=$(printf '%s' "$response" | python3 -c '
import json
import sys

try:
    data = json.load(sys.stdin)
except Exception:
    raise SystemExit(1)

print(data.get("service", ""))
' 2>/dev/null)

    [ "$service" = "weboql" ]
}

resolve_weboql_url

resolve_motor_url() {
    local candidate
    local response
    local driver

    for candidate in "$MOTOR_URL" "http://localhost:49055" "http://localhost:8203"; do
        [ -n "$candidate" ] || continue

        response=$(curl -sf "$candidate/health" 2>/dev/null)
        if [ $? -ne 0 ]; then
            continue
        fi

        driver=$(printf '%s' "$response" | python3 -c '
import json
import sys

try:
    data = json.load(sys.stdin)
except Exception:
    raise SystemExit(1)

print(data.get("driver", ""))
' 2>/dev/null)

        if [ "$driver" = "DRI0050" ]; then
            MOTOR_URL_EFFECTIVE="$candidate"
            return 0
        fi
    done

    MOTOR_URL_EFFECTIVE=""
    return 1
}

# 1. UI route check
echo "1. UI Route Check"
run_test "WebOQL editor route is reachable" "curl -sf ${WEB_URL}/editor"
echo ""

# 2. Health endpoint
echo "2. Health Endpoint"
run_test "Health endpoint" "check_weboql_health"
echo ""

# 3. System status
echo "3. System Status"
run_test "System status endpoint" "curl -sf ${API_BASE}/status"
if curl -sf ${API_BASE}/status > /dev/null 2>&1; then
    echo "Status response:"
    curl -s ${API_BASE}/status | python3 -m json.tool
fi
echo ""

# 4. Direct motor-service health
echo "4. Motor Service Health"
if resolve_motor_url; then
    run_test "rpi-motor-DRI0050 health endpoint" "curl -sf ${MOTOR_URL_EFFECTIVE}/health"
else
    echo -e "${RED}FAIL${NC}"
    ((TESTS_FAILED++))
    echo "  Tried: ${MOTOR_URL}/health, http://localhost:49055/health, http://localhost:8203/health"
fi
if [ -n "$MOTOR_URL_EFFECTIVE" ] && curl -sf ${MOTOR_URL_EFFECTIVE}/health > /dev/null 2>&1; then
    echo "Motor response:"
    curl -s ${MOTOR_URL_EFFECTIVE}/health | python3 -m json.tool
fi
echo ""

# 5. File listing
echo "5. File Listing"
run_test "File listing endpoint" "curl -sf ${API_BASE}/files"
if curl -sf ${API_BASE}/files > /dev/null 2>&1; then
    FILE_COUNT=$(curl -s ${API_BASE}/files | python3 -c "import sys, json; print(len(json.load(sys.stdin)['files']))" 2>/dev/null || echo "0")
    echo "Found ${FILE_COUNT} scenario files"
fi
echo ""

# 6. File reading
echo "6. File Reading"
run_test "Read test-pompy.oql" "curl -sf ${API_BASE}/file/test-pompy.oql"
echo ""

# 7. Scenario execution (mock mode)
echo "7. Scenario Execution (Mock Mode)"
EXECUTION_ID="e2e-test-$(date +%s)"
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%S.%3NZ")
run_test "Execute scenario in mock mode" "curl -sf -X POST ${API_BASE}/execute -H 'Content-Type: application/json' -d '{\"scenario_file\": \"test-pompy.oql\", \"mode\": \"mock\", \"speed\": 1.0, \"execution_id\": \"${EXECUTION_ID}\", \"timestamp\": \"${TIMESTAMP}\"}'"
echo ""

# 8. URL parameters
echo "8. URL Parameters"
run_test "URL parameters with file, mode, speed" "curl -sf '${WEB_URL}/?file=test-pompy.oql&mode=mock&speed=1.0'"
echo ""

# 9. Hardware availability check
echo "9. Hardware Availability"
if curl -sf ${API_BASE}/status > /dev/null 2>&1; then
    STATUS=$(curl -s ${API_BASE}/status)
    PIADC_AVAILABLE=$(echo $STATUS | python3 -c "import sys, json; print(json.load(sys.stdin).get('piadc_available', False))" 2>/dev/null || echo "False")
    MOTOR_AVAILABLE=$(echo $STATUS | python3 -c "import sys, json; print(json.load(sys.stdin).get('motor_available', False))" 2>/dev/null || echo "False")
    MODBUS_AVAILABLE=$(echo $STATUS | python3 -c "import sys, json; print(json.load(sys.stdin).get('modbus_available', False))" 2>/dev/null || echo "False")

    echo "PIADC Available: $([ "$PIADC_AVAILABLE" = "True" ] && echo -e "${GREEN}Yes${NC}" || echo -e "${RED}No${NC}")"
    echo "Motor Available: $([ "$MOTOR_AVAILABLE" = "True" ] && echo -e "${GREEN}Yes${NC}" || echo -e "${RED}No${NC}")"
    echo "Modbus Available: $([ "$MODBUS_AVAILABLE" = "True" ] && echo -e "${GREEN}Yes${NC}" || echo -e "${RED}No${NC}")"
    echo "Motor Service URL: ${MOTOR_URL_EFFECTIVE:-${MOTOR_URL}}"
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
