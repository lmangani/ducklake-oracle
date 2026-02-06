#!/bin/bash
# Test script for DuckLake installation
# This script performs basic validation without requiring sudo

# Don't use set -e because we want to continue on failures
set +e

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASSED=0
FAILED=0

test_pass() {
    echo -e "${GREEN}✓${NC} $1"
    ((PASSED++))
}

test_fail() {
    echo -e "${RED}✗${NC} $1"
    ((FAILED++))
}

test_warn() {
    echo -e "${YELLOW}!${NC} $1"
}

echo "DuckLake Installation Test"
echo "==========================="
echo ""

# Test 1: Check install.sh exists and is executable
if [ -x "install.sh" ]; then
    test_pass "install.sh exists and is executable"
else
    test_fail "install.sh not found or not executable"
fi

# Test 2: Check ducklake-service.sh exists and is executable
if [ -x "ducklake-service.sh" ]; then
    test_pass "ducklake-service.sh exists and is executable"
else
    test_fail "ducklake-service.sh not found or not executable"
fi

# Test 3: Check scripts have valid bash syntax
if bash -n install.sh 2>/dev/null; then
    test_pass "install.sh has valid syntax"
else
    test_fail "install.sh has syntax errors"
fi

if bash -n ducklake-service.sh 2>/dev/null; then
    test_pass "ducklake-service.sh has valid syntax"
else
    test_fail "ducklake-service.sh has syntax errors"
fi

# Test 4: Check help commands work
if ./install.sh --help >/dev/null 2>&1; then
    test_pass "install.sh --help works"
else
    test_fail "install.sh --help failed"
fi

if ./ducklake-service.sh --help >/dev/null 2>&1; then
    test_pass "ducklake-service.sh --help works"
else
    test_fail "ducklake-service.sh --help failed"
fi

# Test 5: Check configuration sample exists
if [ -f "ducklake.conf.sample" ]; then
    test_pass "ducklake.conf.sample exists"
else
    test_fail "ducklake.conf.sample not found"
fi

# Test 6: Check README exists
if [ -f "README.md" ]; then
    test_pass "README.md exists"
    
    # Check README has key sections
    if grep -q "Quick Start" README.md; then
        test_pass "README has Quick Start section"
    else
        test_warn "README missing Quick Start section"
    fi
    
    if grep -q "Installation" README.md; then
        test_pass "README has Installation section"
    else
        test_warn "README missing Installation section"
    fi
else
    test_fail "README.md not found"
fi

# Test 7: Check QUICKSTART exists
if [ -f "QUICKSTART.md" ]; then
    test_pass "QUICKSTART.md exists"
else
    test_warn "QUICKSTART.md not found (optional)"
fi

# Test 8: Check EXAMPLES exists
if [ -f "EXAMPLES.md" ]; then
    test_pass "EXAMPLES.md exists"
else
    test_warn "EXAMPLES.md not found (optional)"
fi

# Test 9: Verify no old complex files remain
OLD_FILES=("Makefile" "config/deploy.py" ".env.sample" "init.sql" "ARCHITECTURE.md")
OLD_FOUND=0
for file in "${OLD_FILES[@]}"; do
    if [ -e "$file" ]; then
        test_fail "Old file still exists: $file"
        OLD_FOUND=1
    fi
done

if [ $OLD_FOUND -eq 0 ]; then
    test_pass "No old complex files remain"
fi

# Test 10: Check scripts use correct paths
if grep -q "/var/lib/ducklake" install.sh; then
    test_pass "install.sh uses correct default data path"
else
    test_warn "install.sh may not use correct default data path"
fi

if grep -q "/etc/ducklake.conf" ducklake-service.sh; then
    test_pass "ducklake-service.sh uses correct config path"
else
    test_warn "ducklake-service.sh may not use correct config path"
fi

# Test 11: Check install script has required components
REQUIRED_IN_INSTALL=("DuckDB" "SQLite" "systemd")
for component in "${REQUIRED_IN_INSTALL[@]}"; do
    if grep -qi "$component" install.sh; then
        test_pass "install.sh mentions $component"
    else
        test_warn "install.sh may not handle $component"
    fi
done

# Test 12: Check service script has required commands
REQUIRED_COMMANDS=("start" "status" "query")
for cmd in "${REQUIRED_COMMANDS[@]}"; do
    if grep -q "$cmd)" ducklake-service.sh; then
        test_pass "ducklake-service.sh supports '$cmd' command"
    else
        test_fail "ducklake-service.sh missing '$cmd' command"
    fi
done

# Test 13: Check config sample has storage options
if grep -q "STORAGE_TYPE=local" ducklake.conf.sample; then
    test_pass "ducklake.conf.sample has local storage config"
else
    test_fail "ducklake.conf.sample missing local storage config"
fi

if grep -q "S3_" ducklake.conf.sample; then
    test_pass "ducklake.conf.sample has S3 storage config"
else
    test_warn "ducklake.conf.sample missing S3 storage config"
fi

# Summary
echo ""
echo "==========================="
echo "Test Summary"
echo "==========================="
echo -e "${GREEN}Passed:${NC} $PASSED"
echo -e "${RED}Failed:${NC} $FAILED"

if [ $FAILED -eq 0 ]; then
    echo ""
    echo -e "${GREEN}All tests passed!${NC}"
    echo ""
    echo "The repository is properly configured."
    echo "Run 'sudo ./install.sh' to install DuckLake."
    exit 0
else
    echo ""
    echo -e "${RED}Some tests failed.${NC}"
    echo "Please review the failures above."
    exit 1
fi
