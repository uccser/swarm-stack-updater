RESPONSE=$(curl -G -s -u https://api.github.com/repos/uccser/cs-field-guide/actions/runs -d "per_page=8")


# can use tag for prod or "develop" for development branch
BRANCH="develop"

WORK_FLOW_RUNS=$(jq -r -n --argjson data "${RESPONSE}" '$data.workflow_runs[] | select(.head_branch == "'"${BRANCH}"'" and .name == "Test and deploy") | any ')

echo ${WORK_FLOW_RUNS}
