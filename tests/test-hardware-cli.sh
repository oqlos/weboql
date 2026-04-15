#!/bin/bash
# CLI tests for oqlos hardware functionality
# Usage: ./tests/test-hardware-cli.sh

set +e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WEBOQL_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
OQLOS_ROOT="$(cd "$WEBOQL_ROOT/../oqlos" && pwd)"
SCENARIOS_DIR="$OQLOS_ROOT/oqlos/scenarios"
OQLCTL_BIN="${OQLCTL_BIN:-$WEBOQL_ROOT/../venv/bin/oqlctl}"
FIRMWARE_URL="${FIRMWARE_URL:-http://localhost:8202}"

if [ ! -x "$OQLCTL_BIN" ]; then
    OQLCTL_BIN="$(command -v oqlctl 2>/dev/null || true)"
fi

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

if [ -z "$OQLCTL_BIN" ]; then
    echo -e "${RED}oqlctl not found. Install oqlos: pip install -e ../oqlos${NC}"
    exit 1
fi

cd "$OQLOS_ROOT" || exit 1

export HARDWARE_MODE="${HARDWARE_MODE:-real}"

# Function to run a command and check exit status only.
run_test() {
    local test_name=$1
    local command=$2

    echo -n "Testing: $test_name... "
    if eval "$command" > /dev/null 2>&1; then
        echo -e "${GREEN}PASS${NC}"
        ((TESTS_PASSED++))
        return 0
    fi

    echo -e "${RED}FAIL${NC}"
    ((TESTS_FAILED++))
    return 1
}

# Function to run an oqlctl command that emits JSON and require ok=true.
run_json_ok_test() {
    local test_name=$1
    local command=$2
    local output
    local status
    local ok

    echo -n "Testing: $test_name... "
    output=$(eval "$command" 2>&1)
    status=$?

    if [ $status -ne 0 ]; then
        echo -e "${RED}FAIL${NC}"
        ((TESTS_FAILED++))
        printf '%s\n' "$output"
        return 1
    fi

    ok=$(printf '%s' "$output" | python3 -c 'import json, sys; data = json.load(sys.stdin); print("true" if data.get("ok") else "false")' 2>/dev/null)
    if [ $? -ne 0 ]; then
        echo -e "${RED}FAIL${NC}"
        ((TESTS_FAILED++))
        printf '%s\n' "$output"
        return 1
    fi

    if [ "$ok" = "true" ]; then
        echo -e "${GREEN}PASS${NC}"
        ((TESTS_PASSED++))
        return 0
    fi

    echo -e "${RED}FAIL${NC}"
    ((TESTS_FAILED++))
    printf '%s\n' "$output"
    return 1
}

# Function to check a health endpoint before running a real hardware smoke test.
check_health() {
    local test_name=$1
    local url=$2

    echo -n "Testing: $test_name... "
    if curl -sf "$url" > /dev/null 2>&1; then
        echo -e "${GREEN}PASS${NC}"
        ((TESTS_PASSED++))
        return 0
    fi

    echo -e "${RED}FAIL${NC}"
    ((TESTS_FAILED++))
    echo "  URL: $url"
    return 1
}

check_motor_ready() {
    local health_json
    local identify_json
    local motor_health
    local dri_status

    echo -n "Testing: Pump hardware readiness... "

    health_json=$(curl -sf "$FIRMWARE_URL/api/v1/hardware/health" 2>/dev/null)
    if [ $? -ne 0 ]; then
        echo -e "${RED}FAIL${NC}"
        ((TESTS_FAILED++))
        echo "  Could not read firmware hardware health"
        return 1
    fi

    motor_health=$(printf '%s' "$health_json" | python3 -c 'import json,sys; print(json.load(sys.stdin).get("motor", ""))' 2>/dev/null)
    if [ "$motor_health" != "ok" ]; then
        echo -e "${RED}FAIL${NC}"
        ((TESTS_FAILED++))
        echo "  Firmware motor health: ${motor_health:-unknown}"
        return 1
    fi

    identify_json=$(curl -sf "$FIRMWARE_URL/api/v1/hardware/identify" 2>/dev/null)
    if [ $? -ne 0 ]; then
        echo -e "${RED}FAIL${NC}"
        ((TESTS_FAILED++))
        echo "  Could not read firmware hardware identification"
        return 1
    fi

    dri_status=$(printf '%s' "$identify_json" | python3 -c '
import json, sys
data = json.load(sys.stdin)
for adapter in data.get("adapters", []):
    if adapter.get("id") == "motor-dri0050":
        print(adapter.get("status", ""))
        break
else:
    print("")
')
    if [ "$dri_status" != "ok" ]; then
        echo -e "${RED}FAIL${NC}"
        ((TESTS_FAILED++))
        echo "  DRI0050 adapter status: ${dri_status:-missing}"
        return 1
    fi

    echo -e "${GREEN}PASS${NC}"
    ((TESTS_PASSED++))
    return 0
}

check_modbus_ready() {
    local identify_json
    local modbus_status

    echo -n "Testing: Valve hardware readiness... "

    identify_json=$(curl -sf "$FIRMWARE_URL/api/v1/hardware/identify" 2>/dev/null)
    if [ $? -ne 0 ]; then
        echo -e "${RED}FAIL${NC}"
        ((TESTS_FAILED++))
        echo "  Could not read firmware hardware identification"
        return 1
    fi

    modbus_status=$(printf '%s' "$identify_json" | python3 -c '
import json, sys
data = json.load(sys.stdin)
for adapter in data.get("adapters", []):
    if adapter.get("id") == "modbus-io":
        print(adapter.get("status", ""))
        break
else:
    print("")
')
    if [ "$modbus_status" != "ok" ]; then
        echo -e "${RED}FAIL${NC}"
        ((TESTS_FAILED++))
        echo "  Modbus adapter status: ${modbus_status:-missing}"
        return 1
    fi

    echo -e "${GREEN}PASS${NC}"
    ((TESTS_PASSED++))
    return 0
}

# 1. Firmware bridge health (required by real mode execution).
echo "1. Firmware Bridge Health"
check_health "Firmware simulator /api/v1/health" "$FIRMWARE_URL/api/v1/health"
echo ""

# 2. Pump connected via rpi-motor-DRI0050 in real mode.
echo "2. Pump Hardware (rpi-motor-DRI0050, real mode)"
if check_motor_ready; then
    run_json_ok_test "Pump smoke test" "timeout 30 $OQLCTL_BIN -m execute -q --json --skip-waits --firmware-url $FIRMWARE_URL $SCENARIOS_DIR/hardware-pump-smoke.oql"
fi

echo ""

# 3. Valves connected via pimodbus in real mode.
echo "3. Valve Hardware (pimodbus, real mode)"
if check_modbus_ready; then
    run_json_ok_test "Valve smoke test" "timeout 30 $OQLCTL_BIN -m execute -q --json --skip-waits --firmware-url $FIRMWARE_URL $SCENARIOS_DIR/hardware-valves-smoke.oql"
fi
echo ""

# 4. CLI help.
echo "4. CLI Help"
run_test "oqlctl help command" "$OQLCTL_BIN --help"
echo ""

# 5. Validate a known scenario.
echo "5. Scenario Validation"
run_test "Validate test-pompy.oql" "$OQLCTL_BIN -m validate $SCENARIOS_DIR/test-pompy.oql"
echo ""

# 6. Dry-run test.
echo "6. Scenario Dry-Run"
run_test "Dry-run test-pompy.oql" "$OQLCTL_BIN -m dry-run -q $SCENARIOS_DIR/test-pompy.oql"
echo ""

# 7. Validate whole scenario directory.
echo "7. Directory Validation"
run_test "Validate scenarios directory" "$OQLCTL_BIN --validate-dir $SCENARIOS_DIR"
echo ""

# 8. JSON output check.
echo "8. JSON Output"
run_json_ok_test "Dry-run with JSON output" "$OQLCTL_BIN -m dry-run -q --json $SCENARIOS_DIR/test-pompy.oql"
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
fi

echo -e "${RED}Some CLI tests failed!${NC}"
exit 1
