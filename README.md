# Swarm Stack Updater

## How to use:
Create a config file matching this description:
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

Run on swarm from command line (will run once):
```
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock --env-file <path_to_env_file> --mount type=bind,source=<path_to_config_file>,dst=/config.yml swarm_stack_updater:latest 
```

**Or**


Deploy on swarm using docker compose:
```
version: '3.8'

services:
  cron-swarm-stack-updater:
    image: swarm_stack_updater:latest
    volumes:
      - "/var/run/docker.sock:/var/run/docker.sock"
      - type: bind
        source: <path_to_config_file>
        target: /config.yml
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
```




## Requirements
* Website must have a status url that returns a JSON object that contains both 
sha commit hash and a tag version.
* ```{"VERSION_NUMBER": "3.10.0", "GIT_SHA": "a49a111d"}```
* Deployment on swarm requires swarm cronjob running and deployed on swarm
this can be found here https://github.com/crazy-max/swarm-cronjob

