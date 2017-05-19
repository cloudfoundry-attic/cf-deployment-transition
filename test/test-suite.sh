#!/bin/bash

pushd $(dirname $0) > /dev/null
  ./test-ca-keys-required.sh
  ./test-expected-varstore.sh
popd > /dev/null
