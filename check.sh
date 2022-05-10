#!/bin/bash

set -e

# Remove prevous artifacts
rm -rf docker-compose.prod.yml

# Currently using arugments passed into the check script but this could easily 
# be replaced by environment varibles
DEV=false
VALID_ARGS=$(getopt -o du:r: --long dev,url:,repository: -- "$@")
if [[ $? -ne 0 ]]; then
    exit 1;
fi

# Check passed arguments
eval set -- "$VALID_ARGS"
while [ : ]; do
    case "$1" in 
    -d | --dev)
        DEV=true
        shift
        ;;
    -u | --url)
        URL=$2
        shift 2
        ;;
    -r | --repository)
        REPO=$2
        shift 2
        ;;
    --) shift; 
        break 
        ;;
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


download_files () {
    # Function to download the respective composefiles when updating. 
    if $DEV;
        then
            file_url="https://raw.githubusercontent.com/uccser/${REPO}/develop/docker-compose.prod.yml"
        else
            file_url="https://raw.githubusercontent.com/uccser/${REPO}/master/docker-compose.prod.yml"
    fi

    # Get compose file contents and output to file
    wget ${file_url} -q -O docker-compose.prod.yml
}

RESPONSE=$(wget ${URL}status -q -O -)
if [ -z ${RESPONSE+x} ];
    then
        echo "Unable to reach url (${URL}). Exiting..."
        exit;
fi

# Using a bash json interpreter
VERSION_NUMBER=$(jq -r '.VERSION_NUMBER' <<< "$RESPONSE")
GIT_SHA=$(jq -r '.GIT_SHA' <<< "$RESPONSE")

if $DEV; 
    then
        RESPONSE=$(wget https://api.github.com/repos/uccser/${REPO}/commits/develop -q -O -)
        REPO_SHA=$(jq -r '.sha' <<< "$RESPONSE")
        REPO_SHA=${REPO_SHA::${#GIT_SHA}}

        if [ "$REPO_SHA" != "$GIT_SHA" ];
            then
                echo "Update"
                download_files
        fi
    else
        RESPONSE=$(wget https://api.github.com/repos/uccser/${REPO}/releases/latest -q -O -)
        VERSION_TAG=$(jq -r '.name' <<< "$RESPONSE")

        if [ "$VERSION_NUMBER" != "$VERSION_TAG" ];
            then
                echo "Update"
                download_files
        fi
fi

if [ -f "docker-compose.prod.yml" ];
    then
        # Run docker command to deploy the stack
        docker stack deploy -c docker-compose.prod.yml test
fi

