#!/bin/bash

root_dir=$PWD/$(dirname $0)
examples_failed=0

DESCRIBE="When on the happy journey"
  IT="makes a vars store from source manifests"
    pushd $(mktemp -d) > /dev/null
      ${root_dir}/../transition.sh \
        -cf ${root_dir}/fixture/source-cf-manifest.yml \
        -d  ${root_dir}/fixture/source-diego-manifest.yml \
        -ca ${root_dir}/fixture/ca-private-keys.yml > /dev/null

      diff -wB -C5 ${root_dir}/fixture/expected-vars-store.yml deployment-vars.yml
      status=$?

      if [ "$status" == "0" ]; then
        echo PASS - ${IT}
      else
        echo FAIL - ${IT}
        examples_failed=1
      fi
    popd > /dev/null

  IT="when run without -N, makes a vars store from source manifests that does not include cf-networking vars"
    pushd $(mktemp -d) > /dev/null
      ${root_dir}/../transition.sh \
        -cf ${root_dir}/fixture/source-cf-manifest.yml \
        -d  ${root_dir}/fixture/source-diego-manifest-with-cf-networking.yml \
        -ca ${root_dir}/fixture/ca-private-keys.yml > /dev/null

      diff -wB -C5 ${root_dir}/fixture/expected-vars-store.yml deployment-vars.yml
      status=$?

      if [ "$status" == "0" ]; then
        echo PASS - ${IT}
      else
        echo FAIL - ${IT}
        examples_failed=1
      fi
    popd > /dev/null

  IT="makes a cf-networking vars store from source manifests"
    pushd $(mktemp -d) > /dev/null
      ${root_dir}/../transition.sh \
        -cf ${root_dir}/fixture/source-cf-manifest.yml \
        -d  ${root_dir}/fixture/source-diego-manifest-with-cf-networking.yml \
        -ca ${root_dir}/fixture/source-ca-private-keys-cf-networking.yml \
        -N > /dev/null

      diff -wB -C5 ${root_dir}/fixture/expected-cf-networking-vars.yml deployment-vars.yml
      status=$?

      if [ "$status" == "0" ]; then
        echo PASS - ${IT}
      else
        echo FAIL - ${IT}
        examples_failed=1
      fi
    popd > /dev/null

if [[ "${examples_failed}" > 0 ]]; then
  echo ${DESCRIBE} FAILED!
  exit 1
else
  echo ${DESCRIBE} PASSED!
  exit 0
fi

