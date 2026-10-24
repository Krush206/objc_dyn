#!/bin/bash
# test_gst.sh — Test suite based on GNU Smalltalk syntax
# Tests classic libobjc + GNUstep Base 1.18.0 with Smalltalk-style syntax.
#
# Syntax tested (based on /opt/smalltalk/examples/ and /opt/smalltalk/tests/):
#   - Class lookup: NSObject, NSArray, NSString, etc.
#   - Symbol literals: #foo, #bar
#   - String literals: 'hello'
#   - Variable assignment: x := Object (Smalltalk :=)
#   - Variable retrieval: x
#   - Error handling: undefined classes, bad messages, invalid assignments
#   - Composite: assign then retrieve

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

# Run a single line of input through the shell
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

# Run multiple lines of input through a single shell session
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
echo "  GNU Smalltalk Syntax Test Suite"
echo "  Based on /opt/smalltalk/examples/ and /opt/smalltalk/tests/"
echo "========================================="
echo ""

# --- Test Group 1: Class Lookup (GNU Smalltalk style) ---
echo "--- Test Group 1: Class Lookup ---"

run_test "NSObject class lookup" "NSObject" "NSObject"
run_test "NSArray class lookup" "NSArray" "NSArray"
run_test "NSString class lookup" "NSString" "NSString"
run_test "NSDictionary class lookup" "NSDictionary" "NSDictionary"
run_test "NSNumber class lookup" "NSNumber" "NSNumber"
run_test "NSData class lookup" "NSData" "NSData"
run_test "NSArrayEnumerator class lookup" "NSArrayEnumerator" "NSArrayEnumerator"

# --- Test Group 2: Symbol Literals (#symbol) ---
echo ""
echo "--- Test Group 2: Symbol Literals ---"

run_test "Symbol #foo" '#foo' "#foo"
run_test "Symbol #bar" '#bar' "#bar"
run_test "Symbol #helloWorld" '#helloWorld' "#helloWorld"
run_test "Symbol #Generator" '#Generator' "#Generator"

# --- Test Group 3: String Literals ---
echo ""
echo "--- Test Group 3: String Literals ---"

run_test "Single-quoted string 'hello world'" "'hello world'" "hello world"
run_test "Double-quoted string \"hello world\"" '"hello world"' "hello world"
run_test "Empty string ''" "''" ""

# --- Test Group 4: Variable Assignment (:=) ---
echo ""
echo "--- Test Group 4: Variable Assignment (Smalltalk :=) ---"

run_multi_test "Assign Object to variable, then retrieve" \
    "Object" \
    "x := Object" "x"

run_multi_test "Assign NSString to variable" \
    "NSString" \
    "s := NSString" "s"

run_multi_test "Assign NSArray to variable" \
    "NSArray" \
    "a := NSArray" "a"

# --- Test Group 5: Error Handling ---
echo ""
echo "--- Test Group 5: Error Handling ---"

run_test "Undefined class name" "NonExistentClass" "missing message"
run_test "Bad message on Object" "Object nope:" "bad message"
run_test "Invalid assignment (nothing after :=)" "x :=" "invalid assignment"

# --- Test Group 6: Composite Operations ---
echo ""
echo "--- Test Group 6: Composite Operations ---"

run_multi_test "Assign class to variable, then retrieve" \
    "Object" \
    "c := Object" "c"

run_multi_test "Assign then retrieve (NSString)" \
    "NSString" \
    "myStr := NSString" "myStr"

echo ""
echo "========================================="
echo "  Results: $pass passed, $fail failed"
echo "========================================="

if [ "$fail" -gt 0 ]; then
    exit 1
fi
exit 0
