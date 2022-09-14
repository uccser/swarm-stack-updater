setup() {
    load 'test_helper/common-setup'
    _common_setup
}


@test "can run our script" {
    run project.sh 
    assert_output --partial 'Welcome to our project!'
}