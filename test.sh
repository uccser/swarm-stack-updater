<<<<<<< HEAD
RESPONSE=$(curl -G -s -u https://api.github.com/repos/uccser/cs-field-guide/actions/runs -d "status=in_progress")
=======
RESPONSE=$(curl -G -s -u https://api.github.com/repos/uccser/cs-field-guide/actions/runs -d "per_page=8")

>>>>>>> 47ddd1b7c6923097e7458d9861da6aeabdfa6238

# can use tag for prod or "develop" for development branch
BRANCH="develop"

# Can be optimised, if response is too big might fail
IN_PROGRESS=$(jq -r -n --argjson data "${RESPONSE}" '$data.workflow_runs[] | select(.head_branch == "'"${BRANCH}"'" and .name == "Test and deploy") | any ')

<<<<<<< HEAD
if [ -z "${IN_PROGRESS}" ]; 
    then
        echo false
    else
        
fi
=======
echo ${WORK_FLOW_RUNS}
>>>>>>> 47ddd1b7c6923097e7458d9861da6aeabdfa6238
