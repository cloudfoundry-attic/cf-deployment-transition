#!/bin/bash

pushd $(dirname $0) > /dev/null
  ./test-unhappy-path.sh
  ./test-expected-varstore.sh
popd > /dev/null
