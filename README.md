# Swarm Stack Updater

## How to use:

### Deploying Using Docker
* First create a config file matching this description:
```
---
<stack-name>:
    isdev: <true/false>
    website_url: <website_url>
    repo:
        name: <repo_name>
        organisation: <organisation_name>
        user: <github_username>
```

* Next save that config file as "swarm_updater_config" in your swarm, this can be done <br />
by typing ```docker config create swarm_updater_config <path-to-file>```


* Finally Deploy on swarm using docker compose:
```
version: '3.8'

services:
  cron-swarm-stack-updater:
    image: swarm_stack_updater:latest
    volumes:
      - "/var/run/docker.sock:/var/run/docker.sock"
    env_file: <path_to_env_file>
    deploy:
      mode: replicated
      replicas: 0
      placement:
        constraints:
          - node.role == manager
      restart_policy:
         condition: none
      labels:
          - "swarm.cronjob.enable=true"
          - "swarm.cronjob.schedule=*/2 * * * *" # Testing Update Every Minute
          - "swarm.cronjob.skip-running=true"
      secrets:
        - github_access_token
      configs:
        - swarm_updater_config

configs:
    swarm_updater_config:
        external: true

secrets:
    github_access_token:
        external: true
```

### Running Locally

The tool has been designed specifically to run using docker swarm or compose but it can be run locally if required. I have tryed my best to remove all issues when running locally but it may not be perfect.

* First Clone the repository using following the command:
```
https://github.com/uccser/swarm-stack-updater.git
```
* Then use the following command to pull BATS, which is used for automated testing:
```
git submodule update --init
```
This will pull all the required tools for running and creating tests for this application.



## Requirements
* The tool makes use of the github api and container registry. You may have to update the script to work for other 
repositories and container registries.
* Website must have a status url that returns a JSON object that contains both 
sha commit hash and a tag version.
* ```{"VERSION_NUMBER": "3.10.0", "GIT_SHA": "a49a111d"}```
* Deployment on swarm requires swarm cronjob running and deployed on swarm
this can be found here https://github.com/crazy-max/swarm-cronjob
* From the bottom of the compose file you can see that a secret is required. This should be a github_access_token to allow for multiple requests. More about
docker secrets can be found here: https://docs.docker.com/engine/swarm/secrets/
* Your docker images should also contain some extra information in their manifest files. This is so the app is able to identify whether a new image is available to download.

Manifest JSON should contain at least:
```
...
labels: {
  "org.opencontainers.image.revision": "<commit-sha>"
}
...
```

## Testing
BATS Core is being used to test some of the swarm stack updaters functions. This hopefully ensures that main functionailly of the application is kept consistant as updates and changes are preformed to the tool. 

### Running Tests
All test code can be found under the test folder. In order to run tests ensure that submodules are pulled as per running locally.
To run ensure that you have giving executible permissions to the **run_bats_tests.sh** file and run the file in a bash terminal by typing ```./run_bats_tests.sh```.

### Creating New Tests
New tests can be easly created by making a new .bats file labled with a short description of the tests to be preformed starting with **"test_"**. To ensure that all libraries are enabled including BATS mock start file with a **setup()** function containing the following:

```
setup() {
    load 'test_helper/common-setup'
    _common_setup

    source ./src/swarm_stack_updater.sh
}
```

This enables all of the libraries stored under **/test/test_helper** as well as passes all functions defined in the swarm stack updater for testing. From there define tests by typing:

```
@test '<Group of Tests> | <Description of Individual Test>' {
    // Test Code
    ...
}

```

### More Information
For more information on BATS core follow this link: https://github.com/bats-core/bats-core \
For more information on BATS mock follow this link: https://github.com/buildkite-plugins/bats-mock \
For more information on BATS assert follow this link: https://github.com/bats-core/bats-assert




