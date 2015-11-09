#!/bin/sh

set -e
mkdir build
cp ./pa1-grading.pl build/
cd build
make -f /usr/class/cs143/assignments/PA2/Makefile
cp ../cool.flex .
make lexer
