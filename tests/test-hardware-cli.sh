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
MOTOR_URL="${MOTOR_URL:-http://localhost:49055}"
LUNG_MOTOR_URL="${LUNG_MOTOR_URL:-${STEPPER_URL:-http://localhost:8205}}"

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
MOTOR_SERVICE_READY=0
LUNG_SERVICE_READY=0
MOTOR_SERVICE_URL=""
MOTOR_SERVICE_PAYLOAD=""
LUNG_SERVICE_URL=""
LUNG_SERVICE_PAYLOAD=""

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

probe_motor_service() {
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
            MOTOR_SERVICE_URL="$candidate"
            MOTOR_SERVICE_PAYLOAD="$response"
            return 0
        fi
    done

    MOTOR_SERVICE_URL=""
    MOTOR_SERVICE_PAYLOAD=""
    return 1
}

check_motor_service_health() {
    echo -n "Testing: rpi-motor-DRI0050 /health... "
    if probe_motor_service; then
        echo -e "${GREEN}PASS${NC}"
        MOTOR_SERVICE_READY=1
        ((TESTS_PASSED++))
        echo "  URL: $MOTOR_SERVICE_URL"
        if [ -n "$MOTOR_SERVICE_PAYLOAD" ]; then
            echo "  Response: $MOTOR_SERVICE_PAYLOAD"
        fi
        return 0
    fi

    echo -e "${RED}FAIL${NC}"
    MOTOR_SERVICE_READY=0
    ((TESTS_FAILED++))
    echo "  Tried: $MOTOR_URL/health, http://localhost:49055/health, http://localhost:8203/health"
    return 1
}

probe_lung_service() {
    local candidate
    local response
    local status

    for candidate in "$LUNG_MOTOR_URL" "http://localhost:8205" "http://localhost:5000"; do
        [ -n "$candidate" ] || continue

        response=$(curl -sf "$candidate/api/health" 2>/dev/null)
        if [ $? -ne 0 ]; then
            continue
        fi

        status=$(printf '%s' "$response" | python3 -c '
import json
import sys

try:
    data = json.load(sys.stdin)
except Exception:
    raise SystemExit(1)

print(data.get("status", ""))
' 2>/dev/null)

        if [ "$status" != "ok" ]; then
            continue
        fi

        LUNG_SERVICE_URL="$candidate"
        LUNG_SERVICE_PAYLOAD="$response"
        return 0
    done

    LUNG_SERVICE_URL=""
    LUNG_SERVICE_PAYLOAD=""
    return 1
}

check_lung_service_health() {
    echo -n "Testing: rpi-motor-tic249 /health... "
    if probe_lung_service; then
        echo -e "${GREEN}PASS${NC}"
        LUNG_SERVICE_READY=1
        export LUNG_MOTOR_URL="$LUNG_SERVICE_URL"
        ((TESTS_PASSED++))
        echo "  URL: $LUNG_SERVICE_URL"
        if [ -n "$LUNG_SERVICE_PAYLOAD" ]; then
            echo "  Response: $LUNG_SERVICE_PAYLOAD"
        fi
        return 0
    fi

    echo -e "${RED}FAIL${NC}"
    LUNG_SERVICE_READY=0
    ((TESTS_FAILED++))
    echo "  Tried: $LUNG_MOTOR_URL/api/health, http://localhost:8205/api/health, http://localhost:5000/api/health"
    return 1
}

run_diag_test() {
    local test_name=$1
    local command=$2
    local output
    local status

    echo -n "Testing: $test_name... "
    output=$(eval "$command" 2>&1)
    status=$?

    if [ $status -ne 0 ]; then
        echo -e "${RED}FAIL${NC}"
        ((TESTS_FAILED++))
        printf '%s\n' "$output"
        return 1
    fi

    echo -e "${GREEN}PASS${NC}"
    ((TESTS_PASSED++))
    printf '%s\n' "$output"
    return 0
}

get_adapter_status() {
    local identify_json=$1
    local adapter_id=$2

    printf '%s' "$identify_json" | python3 -c '
import json
import sys

adapter_id = sys.argv[1]
data = json.load(sys.stdin)
for adapter in data.get("adapters", []):
    if adapter.get("id") == adapter_id:
        print(adapter.get("status", ""))
        break
else:
    print("missing")
' "$adapter_id"
}

show_local_port_inventory() {
    python3 -c '
import glob

serial_ports = sorted(set(glob.glob("/dev/ttyACM*") + glob.glob("/dev/ttyUSB*")))
i2c_buses = sorted(glob.glob("/dev/i2c-*"))

print("Local serial ports:")
if serial_ports:
    for device in serial_ports:
        print(" - {}".format(device))
else:
    print(" - none")

print("Local I2C buses:")
if i2c_buses:
    for device in i2c_buses:
        print(" - {}".format(device))
else:
    print(" - none")
'

    if command -v ss >/dev/null 2>&1; then
        echo "Listening TCP ports of interest:"
        ss -ltnH 2>/dev/null | python3 -c '
import sys

interesting = (":5000", ":8202", ":8203", ":8205", ":49055", ":8080", ":502")
lines = [line.rstrip() for line in sys.stdin if any(port in line for port in interesting)]
if lines:
    for line in lines:
        print(" - {}".format(line))
else:
    print(" - none")
'
    fi
}

show_hardware_inventory() {
    local identify_json
    identify_json=$(curl -sf "$FIRMWARE_URL/api/v1/hardware/identify" 2>/dev/null)
    if [ $? -ne 0 ]; then
        return 1
    fi

    printf '%s' "$identify_json" | python3 -c '
import json
import sys

data = json.load(sys.stdin)
diag = data.get("diagnostics", {}) or {}
health = diag.get("health") or {}

print("Hardware identify: {}/{} adapters in {} mode".format(
    data.get("detected", 0),
    data.get("total", 0),
    data.get("mode", "unknown"),
))

if health:
    print("Bridge health:")
    for key in ("mode", "piadc", "motor", "lung", "modbus"):
        if key in health:
            print(" - {}: {}".format(key, health.get(key)))

serial_ports = diag.get("serial_ports") or []
print("Detected serial ports:")
if serial_ports:
    for port in serial_ports:
        bits = [port.get("device", ""), port.get("product", ""), port.get("serial_number", "")]
        bits = [bit for bit in bits if bit]
        print(" - {}".format(" | ".join(bits)))
else:
    print(" - none")

usb_devices = diag.get("usb_devices") or []
print("Detected USB devices:")
if usb_devices:
    for dev in usb_devices:
        vendor = "{}:{}".format(dev.get("vendor_id", ""), dev.get("product_id", ""))
        desc = " ".join(part for part in [dev.get("manufacturer", ""), dev.get("product", ""), dev.get("serial", "")] if part)
        line = " - {}".format(vendor)
        if desc:
            line += " {}".format(desc)
        print(line)
else:
    print(" - none")

i2c_buses = diag.get("i2c_buses") or []
print("Detected I2C buses:")
if i2c_buses:
    for bus in i2c_buses:
        print(" - {}".format(bus))
else:
    print(" - none")

print("Adapter details:")
for adapter in data.get("adapters", []):
    probe = adapter.get("probe") or {}
    details = []
    for key in ("serial_port", "usb_product", "usb_serial", "usb_path", "baudrate", "parity", "bus", "address", "modbus_device_responds", "reason", "note"):
        value = probe.get(key)
        if value not in (None, "", [], {}):
            details.append("{}={}".format(key, value))
    status = adapter.get("status", "unknown")
    suffix = ": {}".format(", ".join(details)) if details else ""
    print(" - {} [{}]{}".format(adapter.get("id", "unknown"), status, suffix))
'
}

check_adapter_ready() {
    local identify_json
    local adapter_id=$1
    local test_name=$2
    local adapter_status

    echo -n "Testing: $test_name... "

    identify_json=$(curl -sf "$FIRMWARE_URL/api/v1/hardware/identify" 2>/dev/null)
    if [ $? -ne 0 ]; then
        echo -e "${RED}FAIL${NC}"
        ((TESTS_FAILED++))
        echo "  Could not read firmware hardware identification"
        return 1
    fi

    adapter_status=$(get_adapter_status "$identify_json" "$adapter_id")
    if [ "$adapter_status" != "ok" ]; then
        echo -e "${RED}FAIL${NC}"
        ((TESTS_FAILED++))
        echo "  Adapter ${adapter_id} status: ${adapter_status:-missing}"
        return 1
    fi

    echo -e "${GREEN}PASS${NC}"
    ((TESTS_PASSED++))
    return 0
}

check_motor_ready() {
    local identify_json
    local motor_adapter_status

    if [ "$MOTOR_SERVICE_READY" -ne 1 ]; then
        echo -n "Testing: Pump hardware readiness... "
        echo -e "${RED}FAIL${NC}"
        ((TESTS_FAILED++))
        echo "  Motor service health check did not pass"
        return 1
    fi

    echo -n "Testing: Pump hardware readiness... "
    identify_json=$(curl -sf "$FIRMWARE_URL/api/v1/hardware/identify" 2>/dev/null)
    if [ $? -ne 0 ]; then
        echo -e "${RED}FAIL${NC}"
        ((TESTS_FAILED++))
        echo "  Could not read firmware hardware identification"
        return 1
    fi

    motor_adapter_status=$(get_adapter_status "$identify_json" "motor-dri0050")
    if [ "$motor_adapter_status" != "ok" ]; then
        echo -e "${RED}FAIL${NC}"
        ((TESTS_FAILED++))
        echo "  Adapter motor-dri0050 status: ${motor_adapter_status:-missing}"
        return 1
    fi

    echo -e "${GREEN}PASS${NC}"
    ((TESTS_PASSED++))
    return 0
}

check_lung_ready() {
    local identify_json
    local lung_adapter_status

    if [ "$LUNG_SERVICE_READY" -ne 1 ]; then
        echo -n "Testing: Lung hardware readiness... "
        echo -e "${RED}FAIL${NC}"
        ((TESTS_FAILED++))
        echo "  Lung service health check did not pass"
        return 1
    fi

    echo -n "Testing: Lung hardware readiness... "
    identify_json=$(curl -sf "$FIRMWARE_URL/api/v1/hardware/identify" 2>/dev/null)
    if [ $? -ne 0 ]; then
        echo -e "${RED}FAIL${NC}"
        ((TESTS_FAILED++))
        echo "  Could not read firmware hardware identification"
        return 1
    fi

    lung_adapter_status=$(get_adapter_status "$identify_json" "motor-tic249")
    if [ "$lung_adapter_status" != "ok" ]; then
        echo -e "${RED}FAIL${NC}"
        ((TESTS_FAILED++))
        echo "  Adapter motor-tic249 status: ${lung_adapter_status:-missing}"
        return 1
    fi

    echo -e "${GREEN}PASS${NC}"
    ((TESTS_PASSED++))
    return 0
}

check_modbus_ready() {
    local identify_json
    local modbus_adapter_status

    echo -n "Testing: Valve hardware readiness... "

    identify_json=$(curl -sf "$FIRMWARE_URL/api/v1/hardware/identify" 2>/dev/null)
    if [ $? -ne 0 ]; then
        echo -e "${RED}FAIL${NC}"
        ((TESTS_FAILED++))
        echo "  Could not read firmware hardware identification"
        return 1
    fi

    modbus_adapter_status=$(get_adapter_status "$identify_json" "modbus-io")
    if [ "$modbus_adapter_status" = "ok" ]; then
        echo -e "${GREEN}PASS${NC}"
        ((TESTS_PASSED++))
        return 0
    fi

    if [ "$modbus_adapter_status" = "adapter-only" ]; then
        echo -e "${YELLOW}WARN${NC}"
        echo "  Adapter modbus-io status: adapter-only — continuing to smoke test valves"
        ((TESTS_PASSED++))
        return 0
    fi

    echo -e "${RED}FAIL${NC}"
    ((TESTS_FAILED++))
    echo "  Adapter modbus-io status: ${modbus_adapter_status:-missing}"
    return 1
}

# 1. Firmware bridge health (required by real mode execution).
echo "1. Firmware Bridge Health"
check_health "Firmware simulator /api/v1/health" "$FIRMWARE_URL/api/v1/health"
echo ""

# 2. Direct motor-service health check.
echo "2. Motor Service Health"
check_motor_service_health

echo ""

# 3. Direct lung-service health check.
echo "3. Lung Service Health"
check_lung_service_health

echo ""

# 4. Port and hardware diagnostics.
echo "4. Port Diagnostics"
run_diag_test "Local serial/I2C/TCP port inventory" "show_local_port_inventory"
echo ""

# 5. Hardware Inventory
echo "5. Hardware Inventory"
run_diag_test "Firmware identify diagnostics" "show_hardware_inventory"
echo ""

# 6. Pump connected via rpi-motor-DRI0050 in real mode.
echo "6. Pump Hardware (rpi-motor-DRI0050, real mode)"
if check_motor_ready; then
    run_json_ok_test "Pump smoke test" "timeout 30 $OQLCTL_BIN -m execute -q --json --skip-waits --firmware-url $FIRMWARE_URL $SCENARIOS_DIR/hardware-pump-smoke.oql"
fi

echo ""

# 7. Artificial lung connected via rpi-motor-tic249 in real mode.
echo "7. Lung Hardware (rpi-motor-tic249, real mode)"
if check_lung_ready; then
    run_json_ok_test "Lung smoke test" "timeout 30 $OQLCTL_BIN -m execute -q --json --firmware-url $FIRMWARE_URL $SCENARIOS_DIR/hardware-lung-smoke.oql"
fi

echo ""

# 8. Valves connected via pimodbus in real mode.
echo "8. Valve Hardware (pimodbus, real mode)"
if check_modbus_ready; then
    run_json_ok_test "Valve smoke test" "timeout 30 $OQLCTL_BIN -m execute -q --json --skip-waits --firmware-url $FIRMWARE_URL $SCENARIOS_DIR/hardware-valves-smoke.oql"
fi
echo ""

# 9. CLI help.
echo "9. CLI Help"
run_test "oqlctl help command" "$OQLCTL_BIN --help"
echo ""

# 10. Validate a known scenario.
echo "10. Scenario Validation"
run_test "Validate test-pompy.oql" "$OQLCTL_BIN -m validate $SCENARIOS_DIR/test-pompy.oql"
echo ""

# 11. Dry-run test.
echo "11. Scenario Dry-Run"
run_test "Dry-run test-pompy.oql" "$OQLCTL_BIN -m dry-run -q $SCENARIOS_DIR/test-pompy.oql"
echo ""

# 12. Directory Validation.
echo "12. Directory Validation"
run_test "Validate scenarios directory" "$OQLCTL_BIN --validate-dir $SCENARIOS_DIR"
echo ""

# 13. JSON output check.
echo "13. JSON Output"
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
