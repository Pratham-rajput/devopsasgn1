#!/bin/bash

echo "=========================================="
echo "        ARITHMETIC OPERATIONS"
echo "=========================================="

# a. Declare variables
name="DevOps Student"
integer=100
current_date=$(date)

# b. Read two numbers from the user
echo ""
read -p "Enter the first number: " num1
read -p "Enter the second number: " num2

# c. Perform arithmetic operations
sum=$((num1 + num2))
difference=$((num1 - num2))
product=$((num1 * num2))

# Avoid division by zero
if [ "$num2" -ne 0 ]; then
    quotient=$((num1 / num2))
    modulus=$((num1 % num2))
else
    quotient="Undefined (division by zero)"
    modulus="Undefined (division by zero)"
fi

# Print results
echo ""
echo "---------- Arithmetic Results ----------"
echo "Sum        : $sum"
echo "Difference : $difference"
echo "Product    : $product"
echo "Quotient   : $quotient"
echo "Modulus    : $modulus"

# d. Formatted summary
echo ""
echo "=========================================="
echo "           FINAL SUMMARY"
echo "=========================================="
echo "String Variable  : $name"
echo "Integer Variable : $integer"
echo "Current Date     : $current_date"
echo "First Number     : $num1"
echo "Second Number    : $num2"
echo "Sum              : $sum"
echo "Difference       : $difference"
echo "Product          : $product"
echo "Quotient         : $quotient"
echo "Modulus          : $modulus"
echo "=========================================="
