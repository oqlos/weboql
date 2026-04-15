# WebOQL E2E Tests

End-to-end tests for WebOQL service to verify system functionality.

## Test Files

### `e2e.sh` - Bash/Curl Tests
Runs a comprehensive set of E2E tests against the WebOQL service using curl.

The script auto-detects the local WebOQL base URL from common ports and still
honors an explicit `WEB_URL` override when you want to target a specific instance.

**Usage:**
```bash
cd /home/tom/github/oqlos/weboql
./tests/e2e.sh
```

**Or via Makefile:**
```bash
make test-e2e
```

**Tests:**
1. Health Check - Service running
2. Health Endpoint - `/health` endpoint
3. System Status - `/api/v1/editor/status` endpoint
4. File Listing - `/api/v1/editor/files` endpoint
5. File Reading - `/api/v1/editor/file/{name}` endpoint
6. Scenario Execution (Mock) - `/api/v1/editor/execute` endpoint
7. URL Parameters - URL parameter handling
8. Hardware Availability - Hardware service detection

### `test-hardware-cli.sh` - OqlOS CLI Hardware Smoke Tests
Runs `oqlctl` directly from the `oqlos` project root and checks the hardware in this order:
1. Firmware bridge health (`/api/v1/health`)
2. Direct `rpi-motor-DRI0050` service health (`MOTOR_URL/health`)
3. Direct `rpi-motor-tic249` service health (`LUNG_MOTOR_URL/api/health`, default `http://localhost:8205`)
4. Port diagnostics: local `ttyACM` / `ttyUSB` / `i2c` inventory and listening TCP ports
5. Firmware hardware inventory (`/api/v1/hardware/identify`) with adapter, serial, USB, and bus details
6. Pump smoke test via `rpi-motor-DRI0050` in `execute` mode
7. Lung smoke test via `rpi-motor-tic249` in `execute` mode
8. Valve smoke test via `pimodbus` in `execute` mode
9. CLI help, validate, dry-run, directory validation, and JSON output checks

**Usage:**
```bash
cd /home/tom/github/oqlos/weboql
./tests/test-hardware-cli.sh
```

**Or via Makefile:**
```bash
make test-hardware-cli
```

**Valve smoke scenario:**
- `../oqlos/oqlos/scenarios/hardware-valves-smoke.oql`

**Pump smoke scenario:**
- `../oqlos/oqlos/scenarios/hardware-pump-smoke.oql`

**Lung smoke scenario:**
- `../oqlos/oqlos/scenarios/hardware-lung-smoke.oql`

The direct `rpi-motor-DRI0050` health check is the fastest way to confirm the motor service is reachable.
The pump smoke test is still the authoritative hardware execution check for the motor path.
If either fails, the output usually means the firmware bridge or motor service is not reachable,
or the motor hardware itself is not responding.

The direct motor health checks probe the configured `MOTOR_URL` and common fallback ports
before selecting the first `/health` response that identifies as `DRI0050`.

The direct lung health checks probe the configured `LUNG_MOTOR_URL` and common fallback ports
before selecting the first `/health` response that reaches the Tic T249 service.

### `e2e.yaml` - Ansible Playbook
Ansible playbook for automated E2E testing.

The playbook now includes a dedicated `rpi-motor-DRI0050` health check and a firmware
`/api/v1/hardware/identify` inventory dump so serial ports, USB devices, and I2C buses
are visible during troubleshooting.

**Usage:**
```bash
cd /home/tom/github/oqlos/weboql
ansible-playbook -i localhost, -c local tests/e2e.yaml
```

**Requirements:**
- Ansible installed on the system
- WebOQL service running on port 8203

## Test Results

All tests should pass with the following expected status:
- ✅ Health Check: PASS
- ✅ Health Endpoint: PASS
- ✅ System Status: PASS
- ✅ File Listing: PASS (25+ files)
- ✅ File Reading: PASS
- ✅ Mock Execution: PASS
- ✅ URL Parameters: PASS
- ⚠️  Hardware Availability: Mixed (PIADC unavailable without service)
- ✅ Pump Hardware Smoke Test: PASS when `rpi-motor-DRI0050` is connected and reachable
- ✅ Valve Hardware Smoke Test: PASS when `pimodbus` / RS485 / Modbus RTU device is reachable

## Hardware Status

The tests check hardware service availability:
- **PIADC**: Requires service on port 8080
- **Motor**: Checks if service is accessible on `MOTOR_URL` and is detected by firmware identify
- **Modbus**: Checks if serial port `/dev/ttyACM1` exists and firmware identify sees the adapter
- **Diagnostics**: Lists local serial ports, I2C buses, USB devices, and relevant listening TCP ports

For CLI smoke tests, the important part is that the interpreter runs in `execute` mode with `HARDWARE_MODE=real` so the pump and valves are tested against real hardware.

## Troubleshooting

If tests fail:
1. Ensure WebOQL service is running: `make run`
2. Check port 8203 is not in use: `lsof -i :8203`
3. Verify scenarios directory exists
4. Check hardware service URLs in `.env` file

## CI/CD Integration

These tests can be integrated into CI/CD pipelines:
- Run `make test-e2e` after deployment
- Use Ansible playbook for automated testing
- Monitor hardware availability in production
