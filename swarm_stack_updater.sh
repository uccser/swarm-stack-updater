#!/bin/sh

set -e

# Defines function to 

write_log() {
                    # Very Basic Timestamp Logging For Tool
                    #
    _MESSAGE=$1     # The message to be logged

    # Grab a time stamp currently in UTC
    TIME=$(date +%Y-%m-%d\ %H:%M:%S)

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

image_creation_in_progress() {
                # Checks if a website image is still being generated
                # 
    _ORG=$1     # The organisation that hosts the provided repository on Github
    _REPO=$2    # The name of the repository we are checking
    _BRANCH=$3  # The branch that is being checked

    RESPONSE=$(curl -G -s -u ${USER}:${ACCESS_TOKEN} https://api.github.com/repos/${_ORG}/${_REPO}/actions/runs -d "status=in_progress")
    IN_PROGRESS=$(jq -r -n --argjson data "${RESPONSE}" '$data.workflow_runs[] | select(.head_branch == "'"${_BRANCH}"'" and .name == "Test and deploy") | any ')

    if [ -z "${IN_PROGRESS}" ]; 
        then
            # If no image creation is in progress
            return 1
        else
            # If image is currently being created
            return 0  
    fi
}


check_env_variable_exists() { 
                # Checks to see if environment varibles exist
                #
    _VAR=$1     # The environment varible to be checked

    VAL=$(eval "echo \"\$$1\"")
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
    _IS_DEV=$1      # A boolean representing whether to access the development or production branch
    _ORG=$2         # The organisation that hosts the provided repository on Github
    _REPO=$3        # The repository we are downloading from

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

    DEV=$(yq ".$STACK_NAME.isdev" config.yml)
    if [ ${DEV} == null ];
        then
            DEV=false
    fi

    URL=$(yq ".$STACK_NAME.website_url" config.yml)
    REPO=$(yq ".$STACK_NAME.repo.name" config.yml)
    ORG=$(yq ".$STACK_NAME.repo.organisation" config.yml)
    USER=$(yq ".$STACK_NAME.repo.user" config.yml)
    
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

    RESPONSE=$(curl -s -u $USER:$ACCESS_TOKEN ${URL}status/)
    if [ -z ${RESPONSE+x} ];
        then
            write_log "Unable to reach url (${URL}). Skipping..."
            return 1;
    fi

    # Using a bash json interpreter
    VERSION_NUMBER=$(jq -r -n --argjson data "${RESPONSE}" '$data.VERSION_NUMBER')
    GIT_SHA=$(jq -r -n --argjson data "${RESPONSE}" '$data.GIT_SHA')

    if "${DEV}"; 
        then
            RESPONSE=$(curl -s -u $USER:$ACCESS_TOKEN https://api.github.com/repos/${ORG}/${REPO}/commits/develop/)
            REPO_SHA=$(jq -r -n --argjson data "${RESPONSE}" '$data.sha')
            REPO_SHA=${REPO_SHA::${#GIT_SHA}}

            if [ "$REPO_SHA" != "$GIT_SHA" ];
                then
                    # Before pulling files check to see if image has been created
                    if image_creation_in_progress $ORG $REPO "develop";
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
            RESPONSE=$(curl -s -u $USER:$ACCESS_TOKEN https://api.github.com/repos/${ORG}/${REPO}/releases/latest/)
            VERSION_TAG=$(jq -r -n --argjson data "${RESPONSE}" '$data.name')

            if [ "$VERSION_NUMBER" != "$VERSION_TAG" ];
                then
                    # Before pulling files check to see if image has been created
                    if image_creation_in_progress $ORG $REPO $VERSION_TAG;
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

if [ ! -f config.yml ];
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
STACKS=$(yq '.* | key' config.yml)
for stack in $STACKS; do
    update_stack "$stack"
done

exit 0