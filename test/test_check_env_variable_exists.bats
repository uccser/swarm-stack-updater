#!/bin/bash

# bats test file to test environment variable checking function in the swarm stack updater

setup() {
    load 'test_helper/common-setup'
    _common_setup

    source ./src/swarm_stack_updater.sh

    # Mocking Date To Ensure that Date is consistant when testing
    _TEST_DATE="2022-09-14 21:50:10"
    _DATE_ARGS="+%Y-%m-%d\ %H:%M:%S"
    stub date \
        "${_DATE_ARGS} : echo '${_TEST_DATE}'"
}

@test 'Check for environment variable that does exist' {
    export EXIST="Hello"
    local ENV=EXIST
    local expected="${_TEST_DATE} INFO: ${ENV} environment variable found."

    run check_env_variable_exists $ENV
    assert_success
    assert_output "${expected}"
}

@test 'Check for environment variable that does not exist' {
    local ENV=NONE
    local expected="${_TEST_DATE} ERROR: Define ${ENV} environment variable."

    run check_env_variable_exists $ENV
    assert_failure
    assert_output "${expected}"
}

teardown() {
    unstub date    
}

