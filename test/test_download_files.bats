#!/bin/bash

setup() {
    load 'test_helper/common-setup'
    _common_setup

    source ./src/swarm_stack_updater.sh

    USER="tester"
    ACCESS_TOKEN="token"
    _DEFAULT_ARGS="-s -u $USER:$ACCESS_TOKEN"

}

@test 'Correct Arguments passed to curl if IS_DEV is set to true' {
    local expected_org="UCCSER"
    local expected_repo="test-repo"
    local IS_DEV=true

    local expected_url="https://raw.githubusercontent.com/$expected_org/$expected_repo/develop/docker-compose.prod.yml"
    local expected_args="${_DEFAULT_ARGS} ${expected_url} -O"

    stub curl \
        "${expected_args} : echo 'Correct args passed.'"

    run download_files "$IS_DEV" "$expected_org" "$expected_repo"
    assert_success
    assert_output "Correct args passed."
}

@test 'Correct Arguments passed to curl if IS_DEV is set to false' {
    local expected_org="UCCSER"
    local expected_repo="test-repo"
    local IS_DEV=false

    local expected_url="https://raw.githubusercontent.com/$expected_org/$expected_repo/master/docker-compose.prod.yml"
    local expected_args="${_DEFAULT_ARGS} ${expected_url} -O"

    stub curl \
        "${expected_args} : echo 'Correct args passed.'"

    run download_files "$IS_DEV" "$expected_org" "$expected_repo"
    assert_success
    assert_output "Correct args passed."
}

teardown() {
    unstub curl    
}




