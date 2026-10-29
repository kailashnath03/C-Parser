#!/bin/bash
# run_tests.sh - Bash test runner for C Parser Studio
# Usage: bash tests/run_tests.sh [path_to_cparser]

PARSER="${1:-./cparser}"
PASS=0
FAIL=0
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
VALID_DIR="$SCRIPT_DIR/valid"
INVALID_DIR="$SCRIPT_DIR/invalid"

run_test() {
    local file="$1"
    local expect_success="$2"
    local name
    name="$(basename "$file")"

    "$PARSER" "$file" >/dev/null 2>&1
    local code=$?

    if [ "$expect_success" = "1" ]; then
        if [ "$code" = "0" ]; then
            echo "PASS  [valid]   $name"
            return 0
        else
            echo "FAIL  [valid]   $name  (exit $code)"
            "$PARSER" "$file" 2>&1 | head -5 | sed 's/^/      /'
            return 1
        fi
    else
        if [ "$code" != "0" ]; then
            echo "PASS  [invalid] $name  (correctly rejected, exit $code)"
            return 0
        else
            echo "FAIL  [invalid] $name  (should have been rejected)"
            return 1
        fi
    fi
}

echo ""
echo "======================================================"
echo "  C Parser Studio - Automated Test Suite"
echo "  Parser: $PARSER"
echo "======================================================"
echo ""

echo "--- Valid programs (should parse successfully) ---"
for f in "$VALID_DIR"/*.c; do
    if run_test "$f" 1; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); fi
done

echo ""
echo "--- Invalid programs (should be rejected) ---"
for f in "$INVALID_DIR"/*.c; do
    if run_test "$f" 0; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); fi
done

echo ""
echo "======================================================"
TOTAL=$((PASS+FAIL))
echo "  Results: $PASS/$TOTAL passed"
echo "======================================================"
echo ""

[ "$FAIL" = "0" ]

