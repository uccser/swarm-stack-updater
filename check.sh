#!/bin/bash

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
            else
                echo "Dont Update"
        fi
    else
        RESPONSE=$(wget https://api.github.com/repos/uccser/${REPO}/releases/latest -q -O -)
        VERSION_TAG=$(jq -r '.name' <<< "$RESPONSE")

        if [ "$VERSION_NUMBER" != "$VERSION_TAG" ];
            then
                echo "Update"
            else
                echo "Dont Update"
        fi
fi

