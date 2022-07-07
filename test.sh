RESPONSE=$(curl -G -s -u https://api.github.com/repos/uccser/cs-field-guide/actions/runs -d "status=in_progress")

# can use tag for prod or "develop" for development branch
BRANCH="develop"

# Can be optimised, if response is too big might fail
IN_PROGRESS=$(jq -r -n --argjson data "${RESPONSE}" '$data.workflow_runs[] | select(.head_branch == "'"${BRANCH}"'" and .name == "Test and deploy") | any ')

if [ -z "${IN_PROGRESS}" ]; 
    then
        echo false
    else
        
fi