
ARG DOCKER_VER=stable
FROM docker:${DOCKER_VER}

# Add required repository for reading yml filed
RUN echo https://dl-cdn.alpinelinux.org/alpine/edge/community >> /etc/apk/repositories
RUN apk update

# Add tools
RUN apk add jq
RUN apk add yq

COPY swarm_stack_updater.sh /
ENTRYPOINT [ "/swarm_stack_updater.sh"]