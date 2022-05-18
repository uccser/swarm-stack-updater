#!/bin/bash

set -e

checkEnvVariableExists() {
    if [ -z ${!1} ]; 
        then
            echo "ERROR: Define $1 environment variable."
            exit 1
        else
            echo "INFO: $1 environment variable found."
    fi
}

download_files () {
    # Function to download the respective composefiles when updating. 
    if "$1";
        then
            file_url="https://raw.githubusercontent.com/uccser/$2/develop/docker-compose.prod.yml"
        else
            file_url="https://raw.githubusercontent.com/uccser/$2/master/docker-compose.prod.yml"
    fi

    # Get compose file contents and output to file
    wget ${file_url} -q -O docker-compose.prod.yml
}

# Install jq JSON tool if not found (if this was a docker container this could be pre-installed)
if ! command -v jq &> /dev/null; 
    then
        echo "jq could not be found"
        echo "Installing jq..."
        sudo apt install jq
        echo "Done"
fi


DEV=false

# Remove prevous artifacts
rm -rf docker-compose.prod.yml


# Currently using arugments passed into the check script but this could easily 
# be replaced by environment varibles
# Check inputs
while getopts 'du:r:' opt; do
    case "$opt" in
        d) DEV=true     ;;
        u) URL=$OPTARG  ;;
        r) REPO=$OPTARG ;;
    esac
done


if [ -z ${URL+x} ];
    then
        echo "No website url provided. Exiting..."
        exit 1;
fi
echo "Selected Url is: $URL"

if [ -z ${REPO+x} ];
    then
        echo "No repoistory provided. Exiting..."
        exit 1;
fi
echo "Selected Repository is: $REPO"


RESPONSE=$(wget ${URL}status -q -O -)
if [ -z ${RESPONSE+x} ];
    then
        echo "Unable to reach url (${URL}). Exiting..."
        exit 1;
fi

# Using a bash json interpreter
VERSION_NUMBER=$(jq -r '.VERSION_NUMBER' <<< "$RESPONSE")
GIT_SHA=$(jq -r '.GIT_SHA' <<< "$RESPONSE")

if "$DEV"; 
    then
        RESPONSE=$(wget https://api.github.com/repos/uccser/${REPO}/commits/develop -q -O -)
        REPO_SHA=$(jq -r '.sha' <<< "$RESPONSE")
        REPO_SHA=${REPO_SHA::${#GIT_SHA}}

        if [ "$REPO_SHA" != "$GIT_SHA" ];
            then
                echo "Update"
                download_files "$DEV" "$REPO"
            else
                echo "Production ${URL} is already up to date"
                exit 0
        fi
    else
        RESPONSE=$(wget https://api.github.com/repos/uccser/${REPO}/releases/latest -q -O -)
        VERSION_TAG=$(jq -r '.name' <<< "$RESPONSE")

        if [ "$VERSION_NUMBER" != "$VERSION_TAG" ];
            then
                echo "Update"
                download_files "$DEV" "$REPO"
            else
                echo "Development ${URL} is already up to date"
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
        docker stack deploy -c docker-compose.prod.yml "$REPO"

        docker run --rm -it -v /var/run/docker.sock:/var/run/docker.sock sudobmitch/docker-stack-wait "$REPO"

        # Find and run all tasks that have deployed (automatically)
        tasks=$(docker service ls --filter name=${REPO}_task --format "{{.Name}}")
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

