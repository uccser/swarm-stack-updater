#!/bin/bash

setup() {
    load 'test_helper/common-setup'
    _common_setup

    source ./src/swarm_stack_updater.sh

    # test ARGS - These do not matter for these tests
    ORG="uccser"
    REPO="cs-test"
    BRANCH="master"

    # curl ARGS
    USER="tester"
    ACCESS_TOKEN="token"
    _DEFAULT_ARGS="-s -u $USER:$ACCESS_TOKEN"

    # date ARGS
    _TEST_DATE="2022-09-14 21:50:10"
    _DATE_ARGS="+%Y-%m-%d\ %H:%M:%S"
    stub date \
        "${_DATE_ARGS} : echo '${_TEST_DATE}'"

}

@test 'Test image created | Unable to retrieve bearer token' {

    local expected_args="-s -u $USER:$ACCESS_TOKEN 'https://ghcr.io/token?service=ghcr.io&scope=repository:${REPO}:pull'"

    stub curl \
        "${expected_args} : echo 'null'"


    run image_created $ORG $REPO $BRANCH $SHA
    assert_failure
    assert_output "${_TEST_DATE} Unable to retrive bearer token"
}

@test 'Test image created | Unable to retrieve config digest' {

    local BEARER_TOKEN="TOKEN"

    local expected_args1="-s -u $USER:$ACCESS_TOKEN 'https://ghcr.io/token?service=ghcr.io&scope=repository:${REPO}:pull'"
    local expected_args2="-s -H 'Authorization: Bearer ${BEARER_TOKEN}' -H 'Accept: application/vnd.docker.distribution.manifest.v2+json' https://ghcr.io/v2/${ORG}/${REPO}/manifests/${BRANCH}"

    stub curl \
        "${expected_args1} : echo '{\"token\":\"${BEARER_TOKEN}\"}'" \
        "${expected_args2} : echo 'null'"

    run image_created $ORG $REPO $BRANCH $SHA
    assert_failure
    assert_output "${_TEST_DATE} Unable to retrive config digest"
}

@test 'Test image created | Unable to retreve image manifest information' {

    local BEARER_TOKEN="TOKEN"
    local CONFIG_DIGEST="DIGEST"

    local expected_args1="-s -u $USER:$ACCESS_TOKEN 'https://ghcr.io/token?service=ghcr.io&scope=repository:${REPO}:pull'"
    local expected_args2="-s -H 'Authorization: Bearer ${BEARER_TOKEN}' -H 'Accept: application/vnd.docker.distribution.manifest.v2+json' https://ghcr.io/v2/${ORG}/${REPO}/manifests/${BRANCH}"
    local expected_args3="-s -L -H 'Authorization: Bearer ${BEARER_TOKEN}' -H 'Accept: application/vnd.docker.distribution.manifest.v2+json' https://ghcr.io/v2/${ORG}/${REPO}/blobs/${CONFIG_DIGEST}"

    stub curl \
        "${expected_args1} : echo '{\"token\":\"${BEARER_TOKEN}\"}'" \
        "${expected_args2} : echo '{\"config\": { \"digest\": \"${CONFIG_DIGEST}\"}}'" \
        "${expected_args3} : echo 'null'"

    run image_created $ORG $REPO $BRANCH $SHA
    assert_failure
    assert_output "${_TEST_DATE} Image manifest informaton is unavailable."
}


@test 'Test image created | Manifest retreved but image not created' {
    local BEARER_TOKEN="TOKEN"
    local CONFIG_DIGEST="DIGEST"
    local INVALID_SHA="INVALID"
    local SHA="VALID"

    local expected_args1="-s -u $USER:$ACCESS_TOKEN 'https://ghcr.io/token?service=ghcr.io&scope=repository:${REPO}:pull'"
    local expected_args2="-s -H 'Authorization: Bearer ${BEARER_TOKEN}' -H 'Accept: application/vnd.docker.distribution.manifest.v2+json' https://ghcr.io/v2/${ORG}/${REPO}/manifests/${BRANCH}"
    local expected_args3="-s -L -H 'Authorization: Bearer ${BEARER_TOKEN}' -H 'Accept: application/vnd.docker.distribution.manifest.v2+json' https://ghcr.io/v2/${ORG}/${REPO}/blobs/${CONFIG_DIGEST}"

    stub curl \
        "${expected_args1} : echo '{\"token\":\"${BEARER_TOKEN}\"}'" \
        "${expected_args2} : echo '{\"config\": { \"digest\": \"${CONFIG_DIGEST}\"}}'" \
        "${expected_args3} : echo '{\"config\": { \"Labels\": { \"org.opencontainers.image.revision\": \"${INVALID_SHA}\"}}}'"

    run image_created $ORG $REPO $BRANCH $SHA
    assert_failure
    assert_output "${_TEST_DATE} INFO: Image has not been created"
}

@test 'Test image created | Manifest retreved and image created' {
    local BEARER_TOKEN="TOKEN"
    local CONFIG_DIGEST="DIGEST"
    local SHA="VALID"

    local expected_args1="-s -u $USER:$ACCESS_TOKEN 'https://ghcr.io/token?service=ghcr.io&scope=repository:${REPO}:pull'"
    local expected_args2="-s -H 'Authorization: Bearer ${BEARER_TOKEN}' -H 'Accept: application/vnd.docker.distribution.manifest.v2+json' https://ghcr.io/v2/${ORG}/${REPO}/manifests/${BRANCH}"
    local expected_args3="-s -L -H 'Authorization: Bearer ${BEARER_TOKEN}' -H 'Accept: application/vnd.docker.distribution.manifest.v2+json' https://ghcr.io/v2/${ORG}/${REPO}/blobs/${CONFIG_DIGEST}"

    stub curl \
        "${expected_args1} : echo '{\"token\":\"${BEARER_TOKEN}\"}'" \
        "${expected_args2} : echo '{\"config\": { \"digest\": \"${CONFIG_DIGEST}\"}}'" \
        "${expected_args3} : echo '{\"config\": { \"Labels\": { \"org.opencontainers.image.revision\": \"${SHA}\"}}}'"

    run image_created $ORG $REPO $BRANCH $SHA
    assert_success
    assert_output "${_TEST_DATE} INFO: Image has been created"
}




teardown() {
    unstub date
    unstub curl
}

