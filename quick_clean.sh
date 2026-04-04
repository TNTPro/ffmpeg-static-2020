#!/bin/bash

mkdir -p ./b2
mv -v -t ./b2 ./build/*-git
rm -rf bin build target doc man share
mkdir -p ./build
mv -v -t ./build ./b2/*-git
rm -rf b2
rm -rf ./build/rubberband-git

