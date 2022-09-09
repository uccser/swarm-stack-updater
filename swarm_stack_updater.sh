#!/bin/sh

set -e

# Defines function to 

write_log() {
                    # Very Basic Timestamp Logging For Tool
                    #
    local _MESSAGE=$1     # The message to be logged

    # Grab a time stamp currently in UTC
    local TIME=$(date +%Y-%m-%d\ %H:%M:%S)

    if [ -n "${_MESSAGE}" ]; 
        then                            # If it's from a "<message>" then set it
            IN="${_MESSAGE}"
            echo "${TIME} ${IN}" 
        else
            while read IN               # If it is output from command then loop it
            do
                echo "${TIME} ${IN}"
            done
    fi
}

image_created() {
                        # Checks if a website image has been created
                        # 
    local _ORG=$1       # The organisation that hosts the provided repository on Github
    local _REPO=$2      # The name of the repository we are checking
    local _BRANCH=$3    # The branch that is being checked
    local _COMMIT_SHA=$4   # The sha for the most recent commit

    local BEARER_TOKEN=$(curl -s \
        -u username:${ACCESS_TOKEN} \
        "https://ghcr.io/token?service=ghcr.io&scope=repository:${_REPO}:pull" | jq -r '.token')

    local CONFIG_DIGEST=$(curl -s \
        -H "Authorization: Bearer ${BEARER_TOKEN}" \
        -H "Accept: application/vnd.docker.distribution.manifest.v2+json" \
        https://ghcr.io/v2/${_ORG}/${_REPO}/manifests/${_BRANCH} | jq -r .config.digest)

    local IMAGE_SHA=$(curl -s -L \
        -H "Authorization: Bearer ${BEARER_TOKEN}" \
        -H "Accept: application/vnd.docker.distribution.manifest.v2+json" \
        https://ghcr.io/v2/${_ORG}/${_REPO}/blobs/${CONFIG_DIGEST}  | jq -r '.config.Labels."org.opencontainers.image.revision"')

    if [ "$IMAGE_SHA" == "null" ];
        then 
            write_log "Image manifest informaton is unavailable."
            return 1
    fi

    if [ "$_COMMIT_SHA" == "$IMAGE_SHA" ]; 
        then
            # Image has been created
            return 0
        else
            # Image has not been created
            return 1 
    fi
}


check_env_variable_exists() { 
                # Checks to see if environment varibles exist
                #
    local _VAR=$1     # The environment varible to be checked

    local VAL=$(eval "echo \"\$$1\"")
    if [ -z "${VAL}" ]; 
        then
            write_log "ERROR: Define ${_VAR} environment variable."
            return 1 
        else
            write_log "INFO: ${_VAR} environment variable found."     
    fi
}

download_files () {
                    # Function to download the respective composefiles when updating. 
                    #
    local _IS_DEV=$1      # A boolean representing whether to access the development or production branch
    local _ORG=$2         # The organisation that hosts the provided repository on Github
    local _REPO=$3        # The repository we are downloading from

    if "$_IS_DEV";
        then
            file_url="https://raw.githubusercontent.com/$_ORG/$_REPO/develop/docker-compose.prod.yml"
        else
            file_url="https://raw.githubusercontent.com/$_ORG/$_REPO/master/docker-compose.prod.yml"
    fi

    # Get compose file contents and output to file
    curl -s -u $USER:$ACCESS_TOKEN ${file_url} -O
}


update_stack () {
                    # Updates the stack with the provided stack name
                    #
    STACK_NAME=$1   # The stack to be updated

    write_log "Checking stack: $STACK_NAME for updates."

    # Remove prevous artifacts
    rm -rf docker-compose.prod.yml

    DEV=$(yq ".$STACK_NAME.isdev" swarm_updater_config)
    if [ ${DEV} == null ];
        then
            DEV=false
    fi

    URL=$(yq ".$STACK_NAME.website_url" swarm_updater_config)
    REPO=$(yq ".$STACK_NAME.repo.name" swarm_updater_config)
    ORG=$(yq ".$STACK_NAME.repo.organisation" swarm_updater_config)
    USER=$(yq ".$STACK_NAME.repo.user" swarm_updater_config)
    
    if [ -z ${URL+x} ];
        then
            write_log "No website url provided. Skipping..."
            return 1;
    fi

    if [ -z ${REPO+x} ];
        then
            write_log "No repoistory provided. Skipping..."
            return 1;
    fi

    if [ -z ${USER+x} ];
        then
            write_log "No user provided. Skipping..."
            return 1;
    fi

    # Dont want to exit if curl fails
    set +e

        RESPONSE=$(curl -s -f ${URL}/status/)
        if [ -z "$RESPONSE" ];
            then
                write_log "Unable to reach status url (${URL}/status/). Skipping..."
                return 1;
        fi

    set -e

    # Using a bash json interpreter
    VERSION_NUMBER=$(jq -r -n --argjson data "${RESPONSE}" '$data.VERSION_NUMBER')
    GIT_SHA=$(jq -r -n --argjson data "${RESPONSE}" '$data.GIT_SHA')

    if "${DEV}"; 
        then
            # Find most recent commit by a user
            PAGE=0
            COMMIT_SHA=null
            while [ $COMMIT_SHA == "null" ]; do # Assuming that there is always at least one commit that is valid
                curl -G -s -u "${USER}:${ACCESS_TOKEN}" "https://api.github.com/repos/${ORG}/${REPO}/commits" -d "sha=develop" -d "page=$PAGE" -o commits.json 
                COMMIT_SHA=$(jq -n --slurpfile data commits.json '$data[][] | select(.author.type == "User")' | jq -r -s 'first | .sha')
                ((PAGE=PAGE+1))
            done

            # Remove artifacts
            rm commits.json

            if [ "${COMMIT_SHA::${#GIT_SHA}}" != "$GIT_SHA" ];
                then
                    write_log "Current Repoistory SHA: ${COMMIT_SHA::${#GIT_SHA}}. This does not match current website SHA: $GIT_SHA."

                    # Before pulling files check to see if image has been created
                    if ! image_created $ORG $REPO "develop" $COMMIT_SHA;
                        then
                            write_log "Service image not generated yet, skipping."
                            return 0
                    fi

                    write_log "Updating stack $STACK_NAME"
                    download_files "$DEV" "$ORG" "$REPO"
                else
                    write_log "Development: $STACK_NAME is already up to date"
                    return 0
            fi
        else
            VERSION_TAG=$(curl -s -u $USER:$ACCESS_TOKEN https://api.github.com/repos/${ORG}/${REPO}/releases/latest | jq -r '.name')
            COMMIT_SHA=$(curl -s -u $USER:$ACCESS_TOKEN https://api.github.com/repos/${ORG}/${REPO}/git/ref/tags/${VERSION_TAG} | jq -r '.object.sha') 

            if [ "$VERSION_NUMBER" != "$VERSION_TAG" ];
                then
                    write_log "Latest version: $VERSION_TAG. This does not match current website version: $VERSION_NUMBER."

                    # Before pulling files check to see if image has been created
                    if ! image_created $ORG $REPO "latest" $COMMIT_SHA;
                        then
                            write_log "Service image not generated yet, skipping."
                            return 0
                    fi
                    write_log "Updating stack $STACK_NAME"
                    download_files "$DEV" "$ORG" "$REPO"
                else
                    write_log "Production: $STACK_NAME is already up to date"
                    return 0
            fi
    fi

    if [ -f "docker-compose.prod.yml" ];
        then
            
            # Identify environment varibles in file (automatically)
            envs=$(grep '${[A-Z_]*}' docker-compose.prod.yml | awk -vRS="}" -vFS="{" '{print $2}')
            for env in $envs; do
                check_env_variable_exists "$env"
            done 

            # Run docker command to deploy the stack
            docker stack deploy -c docker-compose.prod.yml "$STACK_NAME" | write_log

            docker run --rm -v /var/run/docker.sock:/var/run/docker.sock sudobmitch/docker-stack-wait "$STACK_NAME" | write_log

            # Find and run all tasks that have deployed (automatically)
            tasks=$(docker service ls --filter name=${STACK_NAME}_task --format "{{.Name}}")
            for task in $tasks; do
                docker service scale "$task"=1 -d | write_log
            done

            # Wait for all tasks to finish running then remove the services once tasks are done ie in shutdown state
            tasks_done=false
            until "$tasks_done"; do
                for task in $tasks; do
                    if [ `docker service ps --format "{{.DesiredState}}" ${task}` = 'Shutdown' ];
                        then
                            tasks_done=true
                        else
                            tasks_done=false
                    fi
                done
                sleep 0.2
            done

            # Scale back the tasks once they have been run
            for task in $tasks; do
                docker service scale "$task"=0 -d | write_log
            done
    fi
}


# Install jq JSON tool if not found (if this was a docker container this could be pre-installed)
if ! command -v jq &> /dev/null; 
    then
        write_log "jq could not be found"
        write_log "Installing jq..."
        sudo apt install jq
        write_log "Done"
fi

# Install yq yaml tool if not found (if this was a docker container this could be pre-installed)
if ! command -v yq &> /dev/null;
    then
    write_log "jq could not be found"
    write_log "Installing yq..."
    sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys CC86BB64
    sudo add-apt-repository ppa:rmescandon/yq
    sudo apt update
    sudo apt install yq -y
    write_log "Done"
fi

if [ ! -f swarm_updater_config ];
    then
    write_log "Unable to find config file"
    write_log "Exiting..."
    exit 1
fi

if [ ! -f /run/secrets/github_access_token ];
    then
    write_log "Unable to access github token"
    write_log "Exiting..."
    exit 1
fi

ACCESS_TOKEN=$(cat /run/secrets/github_access_token)
STACKS=$(yq '.* | key' swarm_updater_config)

START_TIME=$(date +%s)
for stack in $STACKS; do
    update_stack "$stack"
done
END_TIME=$(date +%s)
RUNTIME=$((END_TIME-START_TIME))

# Generate and output time
TIME_H=$(($RUNTIME / 3600)); 
TIME_M=$(( ($RUNTIME % 3600) / 60 )); 
TIME_S=$(( ($RUNTIME % 3600) % 60 )); 
write_log "Runtime: $TIME_H:$TIME_M:$TIME_S (hh:mm:ss)"

exit 0
