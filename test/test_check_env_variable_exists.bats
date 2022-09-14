#!/bin/bash

# bats test file to test environment varible checking function in the swarm stack updater


setup() {
    load 'test_helper/common-setup'
    _common_setup

    source ./src/swarm_stack_updater.sh
}

@test 'assert_output() literal check for want' {
    skip
    export LS=echo "Hello"
    ENV=LS

    run check_env_variable_exists $ENV
    assert_output 'want'

    # On failure, the expected and actual output are displayed.
    # -- output differs --
    # expected : want
    # actual   : have
    # --
}

