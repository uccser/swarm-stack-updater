#!/bin/bash

# bats test file to test the logger function in the swarm stack updater

setup() {
    load 'test_helper/common-setup'
    _common_setup

    source ./src/swarm_stack_updater.sh

    # Mocking Date Function
    _TEST_DATE="2022-09-14 21:50:10"
    _DATE_ARGS="+%Y-%m-%d\ %H:%M:%S"
    stub date \
        "${_DATE_ARGS} : echo '${_TEST_DATE}'"

}

@test 'Testing Logging Function with No Input' {
    run write_log
    refute_output
}

@test 'Testing Logging Function with One Line Input' {
    local expected_message="Testing"

    run write_log "Testing"
    assert_output "${_TEST_DATE} ${expected_message}"
    unstub date 
}

command_log() {
    chmod --help | write_log
}

@test "Testing logging function with Command Input" {
    local expected_message=$(chmod --help | head -n 1)

    run command_log
    assert_output -p "${_TEST_DATE} ${expected_message}"
    unstub date 
}