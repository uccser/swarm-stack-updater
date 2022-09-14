setup() {
    load 'test_helper/common-setup'
    _common_setup
}

@test 'description assert_failure() status only' {
        run swarm_stack_updater.sh
        assert_failure
    
        # On failure, $output is displayed.
        # -- command succeeded, but it was expected to fail --
        # output : Success!
        # --
    }