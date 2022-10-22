# Swarm Stack Updater
The Swarm Stack Updater an automated tool built in shell that can be run periodically on a Docker Swarm to search for and identify any out of date stacks. If any changes are found, this tool automatically downloads, updates, and redeploys software back onto the swarm.

This tool has been specifically enginneered to find and update full Docker Stacks by downloading Docker Compose files from GitHub.
This was after finding tools such as [Watchtower](https://github.com/containrrr/watchtower) or [Shepard](https://github.com/djmaze/shepherd) which only aimed to update individual Docker containers by updating images.
Using Compose files means whole application stacks can be updated and can allow for configuration changes as well.  


## Requirements
* Can only be run in a Docker Swarm.
* The tool makes use of the Github API and Container Registry.
  You may have to update the script to work for other repositories and container registries.
* Website must have a status url that returns a JSON object that contains both SHA-1 commit hash and a tag version.
  ```{"VERSION_NUMBER": "7.1.0", "GIT_SHA": "634d994d771fa23f65bc735bba32317ca71b374d"}```
* Deployment requires [Swarm Cronjob](https://github.com/crazy-max/swarm-cronjob) running and deployed on the Swarm.
* A secret is required for multiple GitHub requests (see the Compose file).
  This must be named ```github_access_token```.
  More about Docker Secrets can be found in the [Docker documentation](https://docs.docker.com/engine/swarm/secrets/).

* The Docker images must contain additional information in their manifest files.
  This is so the tool can identify whether a new image is available to download.

Manifest JSON should contain at least:
```
...
labels: {
  "org.opencontainers.image.revision": "<commit-sha>"
}
...
```
An [example is available within the CS Unplugged repostiory](https://github.com/uccser/cs-unplugged/blob/develop/infrastructure/production/django/Dockerfile#L28-L36).

## Deployment:

1. First create a config file so that the Swarm Stack Updater is able to recognise what it needs to update.
  This should contain the stack's name, whether you are deploying the tool in a development environment, the websites url that you are updating as well as some repository information.

This should look something like this:
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

2. Next save that config file as "swarm_updater_config" and set it as a config file in your swarm, this can be done by typing the following command (or can be setup as part of step 3 in your deployment compose file). 
```
docker config create swarm_updater_config <path-to-file>
```


3. Deploy on your swarm swarm using Docker Compose. 
* Make sure you include an env file if you need external varibles for deployment. 
* To ensure that the tool can use docker commands add the volume ```/var/run/docker.sock:/var/run/docker.sock``` to give the tool access to the Docker daemon.
* The following relates to [Swarm Cronjob](https://github.com/crazy-max/swarm-cronjob). Here the tool has been setup to run every 2 mins and will not re run if the tool is already running.
```
 labels:
          - "swarm.cronjob.enable=true"
          - "swarm.cronjob.schedule=*/2 * * * *" # Testing Update Every Minute
          - "swarm.cronjob.skip-running=true"
```

An example of a compose file can be seen below:
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

## Development

### Running Locally

The tool has been designed specifically to run using docker swarm or compose but it can be run locally if required. I have tryed my best to remove all issues when running locally but it may not be perfect.

1. Clone the repository using following the command:
```
https://github.com/uccser/swarm-stack-updater.git
```
2. Use the following command to pull BATS, which is used for automated testing.
  This will pull all the required tools for running and creating tests for this application.
```
git submodule update --init
```
3. Ensure that you have a configuration file created and have the requried environment varibles defined. To define environment varibles use the command ```export ENV_VAR=<value>```.

4. Run the swarm updater by running the command ```./src/swarm_stack_updater.sh```.
  You may need to set to to be executible this can be done by typing the command ```chmod +x /src/swarm_stack_updater.sh```

### Testing
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




