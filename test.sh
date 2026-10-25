#!/bin/bash
# test.sh — Test suite for the object-oriented shell
#
# Tests classic libobjc integration with GNUstep Base 1.18.0,
# Smalltalk syntax (:=, #, :), message chaining, and OO message passing.
#
# STRICT SYNTAX: All objects (even classes) require a message.
#   receiver message           — valid
#   receiver msg1 msg2 ...    — valid (chaining)
#   receiver                   — ERROR "missing message"
#   x := receiver              — ERROR (RHS needs message)
#   x := receiver self         — valid
#
# The `self` message returns the receiver (enables chaining and value retrieval).

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
echo "  Strict: All objects require a message"
echo "========================================="
echo ""

# --- Test Group 1: Class Lookup via self ---
echo "--- Class Lookup via self ---"

run_test "NSObject self" "NSObject self" "NSObject"
run_test "NSArray self" "NSArray self" "NSArray"
run_test "NSString self" "NSString self" "NSString"
run_test "NSDictionary self" "NSDictionary self" "NSDictionary"
run_test "NSNumber self" "NSNumber self" "NSNumber"

# --- Test Group 2: Bare Names Error (strict syntax) ---
echo ""
echo "--- Bare Names Error ---"

run_test "Bare NSObject errors" "NSObject" "missing message"
run_test "Bare Object errors" "Object" "missing message"
run_test "Bare NSString errors" "NSString" "missing message"

# --- Test Group 3: Smalltalk Symbol Literals ---
echo ""
echo "--- Smalltalk Symbol Literals (self-evaluating) ---"

run_test "Symbol #foo" '#foo' "#foo"
run_test "Symbol #bar" '#bar' "#bar"
run_test "Symbol #helloWorld" '#helloWorld' "#helloWorld"

# --- Test Group 4: String Literals ---
echo ""
echo "--- String Literals ---"

run_test "Bare string errors" "'hello world'" "missing message"

# --- Test Group 5: Variable Assignment ---
echo ""
echo "--- Variable Assignment (Smalltalk :=) ---"

run_multi_test "Assign Object to x, retrieve via self" \
    "Object" \
    "x := Object self" "x self"

run_multi_test "Assign NSString to s, retrieve via self" \
    "NSString" \
    "s := NSString self" "s self"

run_test "x := Object (no message on RHS) errors" \
    "x := Object" \
    "missing message"

# --- Test Group 6: Message Chaining ---
echo ""
echo "--- Message Chaining (receiver msg1 msg2 ...) ---"

run_test "Object self (returns class)" "Object self" "Object"
run_test "Object self new (creates instance)" "Object self new" "Object"
run_test "Object new (creates instance)" "Object new" "Object"

# --- Test Group 7: Error Handling ---
echo ""
echo "--- Error Handling ---"

run_test "Undefined class name" "NonExistentClass self" "not found"
run_test "Bad message on Object" "Object nope:" "does not recognize"
run_test "Invalid assignment" "x :=" "invalid assignment"

# --- Test Group 8: Composite Operations ---
echo ""
echo "--- Composite Operations ---"

run_multi_test "Assign then message chain" \
    "Object" \
    "c := Object self" "c self new"

echo ""
echo "========================================="
echo "  Results: $pass passed, $fail failed"
echo "========================================="

if [ "$fail" -gt 0 ]; then
    exit 1
fi
exit 0
