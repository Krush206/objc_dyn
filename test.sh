#!/bin/bash
# test.sh — Test suite for the object-oriented shell
#
# Tests classic libobjc integration with GNUstep Base 1.18.0,
# Smalltalk syntax (:=, #, :), and OO message passing.

cd /opt/objc_dyn || exit 1

SH=./sh
pass=0
fail=0

ok() {
    echo "  PASS: $1"
    pass=$((pass + 1))
}

bad() {
    echo "  FAIL: $1"
    fail=$((fail + 1))
}

run_test() {
    local name="$1"
    local input="$2"
    local expected="$3"

    echo "Test: $name"
    local got
    got=$(printf '%s\n' "$input" | timeout 1 "$SH" 2>&1)
    local exit_code=$?

    if echo "$got" | grep -qF "$expected"; then
        ok "$name"
    else
        bad "$name (expected '$expected', got: '$got', exit: $exit_code)"
    fi
}

run_multi_test() {
    local name="$1"
    shift
    local expected="$1"
    shift

    echo "Test: $name"
    local got
    got=$(printf '%s\n' "$@" | timeout 1 "$SH" 2>&1)
    local exit_code=$?

    if echo "$got" | grep -qF "$expected"; then
        ok "$name"
    else
        bad "$name (expected '$expected', got: '$got', exit: $exit_code)"
    fi
}

echo "========================================="
echo "  Object-Oriented Shell Test Suite"
echo "========================================="
echo ""

# --- Test Group 1: Class Lookup ---
echo "--- Class Lookup ---"

run_test "NSObject class lookup" \
    "NSObject" \
    "NSObject"

run_test "NSArray class lookup" \
    "NSArray" \
    "NSArray"

run_test "NSString class lookup" \
    "NSString" \
    "NSString"

run_test "NSDictionary class lookup" \
    "NSDictionary" \
    "NSDictionary"

run_test "NSNumber class lookup" \
    "NSNumber" \
    "NSNumber"

# --- Test Group 2: Smalltalk Symbol Literals ---
echo ""
echo "--- Smalltalk Symbol Literals ---"

run_test "Symbol #foo" \
    '#foo' \
    "#foo"

run_test "Symbol #bar" \
    '#bar' \
    "#bar"

run_test "Symbol #helloWorld" \
    '#helloWorld' \
    "#helloWorld"

# --- Test Group 3: String Literals ---
echo ""
echo "--- String Literals ---"

run_test "Single-quoted string" \
    "'hello world'" \
    "hello world"

run_test "Double-quoted string" \
    '"hello world"' \
    "hello world"

# --- Test Group 4: Variable Assignment ---
echo ""
echo "--- Variable Assignment ---"

run_multi_test "Assign Object to x then retrieve" \
    "Object" \
    "x := Object" "x"

run_multi_test "Assign NSString to s then retrieve" \
    "NSString" \
    "s := NSString" "s"

run_multi_test "Assign then retrieve (Object class)" \
    "Object" \
    "o := Object" "o"

# --- Test Group 5: Error Handling ---
echo ""
echo "--- Error Handling ---"

run_test "Undefined class name" \
    'NonExistentClass' \
    "missing message"

run_test "Bad message on Object" \
    'Object nope:' \
    "bad message"

run_test "Invalid assignment" \
    'x :=' \
    "invalid assignment"

# --- Test Group 6: Composite Operations ---
echo ""
echo "--- Composite Operations ---"

run_multi_test "Assign then retrieve" \
    "Object" \
    "c := Object" "c"

echo ""
echo "========================================="
echo "  Results: $pass passed, $fail failed"
echo "========================================="

if [ "$fail" -gt 0 ]; then
    exit 1
fi
exit 0
