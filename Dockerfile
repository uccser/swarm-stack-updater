
ARG DOCKER_VER=stable
FROM docker:${DOCKER_VER}


# Add required tool for reading yml files
RUN wget https://github.com/mikefarah/yq/releases/download/v4.26.1/yq_linux_386.tar.gz -O - |\
    tar xz && mv yq_linux_386 /usr/bin/yq

# Add tools
RUN apk update
RUN apk add jq
RUN apk add curl

COPY src/swarm_stack_updater.sh /
ENTRYPOINT [ "/swarm_stack_updater.sh"]