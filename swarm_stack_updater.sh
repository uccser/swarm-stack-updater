#!/bin/sh

set -e

checkEnvVariableExists() { 
    # Checks to see if environment varibles exist
    VAL=$(eval "echo \"\$$1\"")
    if [ -z "$VAL" ]; 
        then
            echo "ERROR: Define "$1" environment variable."
            exit 1 
        else
            echo "INFO: "$1" environment variable found."     
    fi
}

download_files () {
    # Function to download the respective composefiles when updating. 
    if "$1";
        then
            file_url="https://raw.githubusercontent.com/$2/$3/develop/docker-compose.prod.yml"
        else
            file_url="https://raw.githubusercontent.com/$2/$3/master/docker-compose.prod.yml"
    fi

    # Get compose file contents and output to file
    wget ${file_url} -q -O docker-compose.prod.yml
}


update_stack () {
    STACK_NAME=$1
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
    
    if [ -z ${URL+x} ];
        then
            echo "No website url provided. Exiting..."
            exit 1;
    fi

    if [ -z ${REPO+x} ];
        then
            echo "No repoistory provided. Exiting..."
            exit 1;
    fi

    RESPONSE=$(wget ${URL}status -q -O -)
    if [ -z ${RESPONSE+x} ];
        then
            echo "Unable to reach url (${URL}). Exiting..."
            exit 1;
    fi

    # Using a bash json interpreter
    VERSION_NUMBER=$(jq -r -n --argjson data "${RESPONSE}" '$data.VERSION_NUMBER' )
    GIT_SHA=$(jq -r -n --argjson data "${RESPONSE}" '$data.GIT_SHA')

    if "${DEV}"; 
        then
            RESPONSE=$(wget https://api.github.com/repos/${ORG}/${REPO}/commits/develop -q -O -)
            REPO_SHA=$(jq -r -n --argjson data "${RESPONSE}" '$data.sha')
            REPO_SHA=${REPO_SHA::${#GIT_SHA}}
            if [ "$REPO_SHA" != "$GIT_SHA" ];
                then
                    echo "Updating stack $STACK_NAME"
                    download_files "$DEV" "$ORG" "$REPO"
                else
                    echo "Development: $STACK_NAME is already up to date"
                    exit 0
            fi
        else
            RESPONSE=$(wget https://api.github.com/repos/${ORG}/${REPO}/releases/latest -q -O -)
            VERSION_TAG=$(jq -r -n --argjson data "${RESPONSE}" '$data.name')

            if [ "$VERSION_NUMBER" != "$VERSION_TAG" ];
                then
                    echo "Updating stack $STACK_NAME"
                    download_files "$DEV" "$ORG" "$REPO"
                else
                    echo "Production: $STACK_NAME is already up to date"
                    exit 0
            fi
    fi

    if [ -f "docker-compose.prod.yml" ];
        then
            
            # Identify environment varibles in file (automatically)
            envs=$(grep '${[A-Z_]*}' docker-compose.prod.yml | awk -vRS="}" -vFS="{" '{print $2}')
            for env in $envs; do
                checkEnvVariableExists "$env"
            done 

            # Run docker command to deploy the stack
            docker stack deploy -c docker-compose.prod.yml "$STACK_NAME"

            docker run --rm -v /var/run/docker.sock:/var/run/docker.sock sudobmitch/docker-stack-wait "$STACK_NAME"

            # Find and run all tasks that have deployed (automatically)
            tasks=$(docker service ls --filter name=${STACK_NAME}_task --format "{{.Name}}")
            for task in $tasks; do
                docker service scale "$task"=1 -d
            done

            # Wait for all tasks to finish running then remove the services once tasks are done ie in shutdown state
            tasks_done=false
            until "$tasks_done"; do
                for task in $tasks; do
                    if [ `docker service ps --format "{{.DesiredState}}" ${task}` = "Shutdown" ];
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
                docker service scale "$task"=0 -d
            done
    fi
}


# Install jq JSON tool if not found (if this was a docker container this could be pre-installed)
if ! command -v jq &> /dev/null; 
    then
        echo "jq could not be found"
        echo "Installing jq..."
        sudo apt install jq
        echo "Done"
fi

# Install yq yaml tool if not found (if this was a docker container this could be pre-installed)
if ! command -v yq &> /dev/null;
    then
    echo "jq could not be found"
    echo "Installing yq..."
    sudo apt-key adv --keyserver keyserver.ubuntu.com --recv-keys CC86BB64
    sudo add-apt-repository ppa:rmescandon/yq
    sudo apt update
    sudo apt install yq -y
    echo "Done"
fi

if [ ! -f config.yml ];
    then
    echo "Unable to find config file"
    echo "Exiting..."
    exit 1
fi

STACKS=$(yq '.* | key' config.yml)
for stack in $STACKS; do
    update_stack "$stack"
done