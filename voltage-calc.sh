#!/bin/bash


# Solve for R2
# $1 is the Vin
# $2 is the Vout (desired voltage)
# $3 is the known resistor value in Ohms
# output is the second resistor value to use to achieve Vout
#echo " ($2*$3)/($1-$2)" | bc

# Solve for V2
# $1 is the Vin
# $2 is resistor 1 (R1) in ohms
# $3 is resistor 2 (R2) in ohms
# output is the achieved Vout
echo "scale=1; ($1*$3)/($2+$3)" | bc

echo ""
echo "Vin ------- R1 ------- R2 ------- Gnd"
echo "                   |"
echo "                   |"
echo "                   |"
echo "                   |"
echo "                   Vout"