# WebOQL E2E Tests

End-to-end tests for WebOQL service to verify system functionality.

## Test Files

### `e2e.sh` - Bash/Curl Tests
Simple bash script using curl to test API endpoints.

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

### `e2e.yaml` - Ansible Playbook
Ansible playbook for automated E2E testing.

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

## Hardware Status

The tests check hardware service availability:
- **PIADC**: Requires service on port 8080
- **Motor**: Checks if service is accessible
- **Modbus**: Checks if serial port `/dev/ttyACM1` exists

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
