# ./swarm_stack_updater.sh -d -u https://www.csfieldguide.org.nz/ -r cs-field-guide

docker run -it --rm -v /var/run/docker.sock:/var/run/docker.sock --env-file ./config_files/.env --mount type=bind,source="$(pwd)"/config_files/config.yml,dst=/config.yml swarm_stack_updater 