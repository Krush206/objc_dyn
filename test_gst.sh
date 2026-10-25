#!/bin/bash
# test_gst.sh — Test suite based on GNU Smalltalk syntax
# Tests classic libobjc + GNUstep Base 1.18.0 with Smalltalk-style syntax.
#
# STRICT SYNTAX: All objects (even classes) require a message.
#   receiver message           — valid
#   receiver msg1 msg2 ...    — valid (chaining)
#   receiver                   — ERROR "missing message"
#
# Syntax tested (based on /opt/smalltalk/examples/ and /opt/smalltalk/tests/):
#   - Class lookup via self: NSObject self
#   - Message chaining: Object self new (creates instance)
#   - Symbol literals: #foo (self-evaluating)
#   - Variable assignment: x := Object self (Smalltalk :=)
#   - Error handling: bare names error, bad messages, invalid assignments

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
run_test "NSData self" "NSData self" "NSData"

# --- Test Group 2: Bare Names Error ---
echo ""
echo "--- Bare Names Error (strict syntax) ---"

run_test "Bare NSObject errors" "NSObject" "missing message"
run_test "Bare Object errors" "Object" "missing message"
run_test "Bare string errors" "'hello'" "missing message"

# --- Test Group 3: Symbol Literals (self-evaluating) ---
echo ""
echo "--- Symbol Literals ---"

run_test "Symbol #foo" '#foo' "#foo"
run_test "Symbol #bar" '#bar' "#bar"
run_test "Symbol #helloWorld" '#helloWorld' "#helloWorld"
run_test "Symbol #Generator" '#Generator' "#Generator"

# --- Test Group 4: Variable Assignment ---
echo ""
echo "--- Variable Assignment (Smalltalk :=) ---"

run_multi_test "Assign Object to x, retrieve via self" \
    "Object" \
    "x := Object self" "x self"

run_multi_test "Assign NSString to s, retrieve via self" \
    "NSString" \
    "s := NSString self" "s self"

run_multi_test "Assign NSArray to a, retrieve via self" \
    "NSArray" \
    "a := NSArray self" "a self"

run_test "x := Object (no message on RHS) errors" \
    "x := Object" \
    "missing message"

# --- Test Group 5: Message Chaining ---
echo ""
echo "--- Message Chaining ---"

run_test "Object self (returns class)" "Object self" "Object"
run_test "Object self new (creates instance)" "Object self new" "Object"
run_test "Object new (creates instance)" "Object new" "Object"

# --- Test Group 6: Error Handling ---
echo ""
echo "--- Error Handling ---"

run_test "Undefined class name" "NonExistentClass self" "nil"
run_test "Bad message on Object" "Object nope:" "does not recognize"
run_test "Invalid assignment" "x :=" "invalid assignment"

# --- Test Group 7: Composite Operations ---
echo ""
echo "--- Composite Operations ---"

run_multi_test "Assign class, then message chain" \
    "Object" \
    "c := Object self" "c self new"

# --- Test Group 8: Declarable Classes ---
echo ""
echo "--- Declarable Classes (Smalltalk subclass: #Name) ---"

run_multi_test "Declare MyClass subclass of Object" \
    "MyClass" \
    "Object subclass: #MyClass"

run_multi_test "Declared class resolves via self" \
    "Object" \
    "Object subclass: #MyClass" \
    "MyClass self"

run_multi_test "Declared class creates instance" \
    "Object" \
    "Object subclass: #MyClass" \
    "MyClass self new"

run_multi_test "Duplicate declaration errors" \
    "class already declared" \
    "Object subclass: #MyClass" \
    "Object subclass: #MyClass"

echo ""
echo "========================================="
echo "  Results: $pass passed, $fail failed"
echo "========================================="

if [ "$fail" -gt 0 ]; then
    exit 1
fi
exit 0
