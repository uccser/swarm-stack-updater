# Swarm Stack Updater

## How to use:
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


## Requirements
* Website must have a status url that returns a JSON object that contains both 
sha commit hash and a tag version.
* ```{"VERSION_NUMBER": "3.10.0", "GIT_SHA": "a49a111d"}```
* Deployment on swarm requires swarm cronjob running and deployed on swarm
this can be found here https://github.com/crazy-max/swarm-cronjob
* From the bottom of the compose file you can see that a secret is required. This should be a github_access_token to allow for multiple requests. More about
docker secrets can be found here: https://docs.docker.com/engine/swarm/secrets/
