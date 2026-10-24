#!/bin/bash
# test_gst.sh — Test suite based on GNU Smalltalk syntax
# Tests classic libobjc + GNUstep Base 1.18.0 with Smalltalk-style syntax.
#
# Syntax tested (based on /opt/smalltalk/examples/ and /opt/smalltalk/tests/):
#   - Class lookup via self: NSObject self, NSArray self
#   - Message chaining: Object self new (creates instance)
#   - Symbol literals: #foo, #bar
#   - String literals: 'hello'
#   - Variable assignment: x := Object (Smalltalk :=)
#   - Error handling: undefined classes, bad messages, invalid assignments

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
echo "  GNU Smalltalk Syntax Test Suite"
echo "  Based on /opt/smalltalk/examples/ and /opt/smalltalk/tests/"
echo "  Message chaining: receiver msg1 msg2 ..."
echo "========================================="
echo ""

# --- Test Group 1: Class Lookup via self ---
echo "--- Test Group 1: Class Lookup via self ---"

run_test "NSObject self" "NSObject self" "NSObject"
run_test "NSArray self" "NSArray self" "NSArray"
run_test "NSString self" "NSString self" "NSString"
run_test "NSDictionary self" "NSDictionary self" "NSDictionary"
run_test "NSNumber self" "NSNumber self" "NSNumber"
run_test "NSData self" "NSData self" "NSData"
run_test "NSArrayEnumerator self" "NSArrayEnumerator self" "NSArrayEnumerator"

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

# --- Test Group 4: Variable Assignment (Smalltalk :=) ---
echo ""
echo "--- Test Group 4: Variable Assignment (Smalltalk :=) ---"

run_multi_test "Assign Object to variable, then retrieve via self" \
    "Object" \
    "x := Object" "x self"

run_multi_test "Assign NSString to variable, then retrieve via self" \
    "NSString" \
    "s := NSString" "s self"

run_multi_test "Assign NSArray to variable, then retrieve via self" \
    "NSArray" \
    "a := NSArray" "a self"

# --- Test Group 5: Message Chaining ---
echo ""
echo "--- Test Group 5: Message Chaining ---"

run_test "Object self (returns class)" "Object self" "Object"
run_test "Object self new (creates instance)" "Object self new" "Object"
run_test "Object new (creates instance)" "Object new" "Object"

# --- Test Group 6: Error Handling ---
echo ""
echo "--- Test Group 6: Error Handling ---"

run_test "Undefined class name" "NonExistentClass self" "not found"
run_test "Bad message on Object" "Object nope:" "does not recognize"
run_test "Invalid assignment (nothing after :=)" "x :=" "invalid assignment"

# --- Test Group 7: Composite Operations ---
echo ""
echo "--- Test Group 7: Composite Operations ---"

run_multi_test "Assign class to variable, then message chain" \
    "Object" \
    "c := Object" "c self new"

echo ""
echo "========================================="
echo "  Results: $pass passed, $fail failed"
echo "========================================="

if [ "$fail" -gt 0 ]; then
    exit 1
fi
exit 0
