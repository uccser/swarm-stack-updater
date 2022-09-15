#!/bin/bash

setup() {
    load 'test_helper/common-setup'
    _common_setup

    source ./src/swarm_stack_updater.sh

    USER="tester"
    ACCESS_TOKEN="token"
    DEFAULT_ARGS=" -s -u $USER:$ACCESS_TOKEN $URL -O"
}

