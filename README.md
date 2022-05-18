# Swarm Stack Updater

## How to use:
To update a stack run command on manager node:
``` ./check.sh -u {website_url} -r {stack_name}```

* Use parameter ```-d``` to run for dev (Uses commit hash to figure out if there is a new version).

## Requirements
* Website must have a status url that returns a JSON object that contains both 
sha commit hash and a tag version.
* ```{"VERSION_NUMBER": "3.10.0", "GIT_SHA": "a49a111d"}```

