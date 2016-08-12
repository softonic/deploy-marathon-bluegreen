#!/usr/bin/env bash
#------------------------------------------------------------------------------
# deploy.sh
#------------------------------------------------------------------------------

[ -z "${PROJECT_COMPONENTS}" ] && echo 'Ops! PROJECT_COMPONENTS is not set' && exit 1
[ -z "${DOCKER_REGISTRY_USER}" ] && echo 'Ops! DOCKER_REGISTRY_USER is not set' && exit 1
[ -z "${PROJECT_NAME}" ] && echo 'Ops! PROJECT_NAME is not set' && exit 1
[ -z "${PROJECT_GROUP}" ] && echo 'Ops! PROJECT_GROUP is not set' && exit 1
[ -z "${PROJECT_VERSION}" ] && echo 'Ops! PROJECT_VERSION is not set' && exit 1
[ -z "${MARATHON_URL}" ] && echo 'Ops! MARATHON_URL is not set' && exit 1
[ -z "${TEMP_FOLDER}" ] && echo 'Ops! TEMP_FOLDER is not set' && exit 1

[ -d $TEMP_FOLDER ] || mkdir $TEMP_FOLDER
echo $MARATHON_URL
MARATHON_TEMP_PATH="$TEMP_FOLDER/marathon.json"

#------------------------------------------------------------------------------
# Compose jsons in an application in marathon and perform global modifications.
#
# @author Daniel Ibáñez Fernández <daniel.ibanez@softonic.com>
#------------------------------------------------------------------------------

function compose_json {

    TOTAL=${#PROJECT_COMPONENTS[@]}
    COUNT=0

    # JSON header:
    echo '{'
    echo "  \"id\": \"$PROJECT_GROUP/$PROJECT_NAME/$ENV/$PROJECT_VERSION\","
    echo '    "apps": ['
    for i in ${PROJECT_COMPONENTS[@]}; do

        # Deployed container with zdd script should be outside marathon.json deployment.
        if [[ $i = $BLUE_GREEN_CONTAINER ]]; then
            env_var | jq ".id |= \"/${PROJECT_GROUP}/${PROJECT_NAME}/${ENV}/${PROJECT_VERSION}/${i}\"" \
                > $TEMP_FOLDER/marathon-blue.${i}.json
        else
            VERSION=$(cat $TEMP_FOLDER/current-version.json | sed 's/"//g')
            INSTANCES=$(dcos marathon app show $VERSION/$i | jq .instances)
            if [ -z "${INSTANCES}" ]; then
                env_var
            else
                env_var | jq .instances=$INSTANCES
            fi
            [ ${COUNT} -lt $((TOTAL-1)) ] && [ $BLUE_GREEN_CONTAINER != ${PROJECT_COMPONENTS[$((COUNT+1))]} ]&& {
              echo -n ','
            }
        fi
        COUNT=$((COUNT+1))
    done

    # JSON footer:
    echo '  ]'
    echo '}'
}

function env_var {
    eval echo $(cat workspace/docker/${i}/marathon.json | sed 's/"/\\"/g')

}

#------------------------------------------------------------------------------
# deploy
#------------------------------------------------------------------------------

function deploy {
    echo "Deploying /$PROJECT_GROUP/$PROJECT_NAME/$ENV/$PROJECT_VERSION/..."
    deployed_version > $TEMP_FOLDER/current-version.json
    compose_json > $MARATHON_TEMP_PATH
    cat $MARATHON_TEMP_PATH | jq .
    deploy_internal_stack
    wait_until_internal_stack_deployed
    deploy_blue_green_component
    delete_old_versions
    rm -rf $TEMP_FOLDER
}

function deployed_version {
    dcos marathon group list --json \
    | jq ".[]?.groups[]?.groups[]? \
    | [select(.apps[].labels.stack_environment == \"$PROJECT_GROUP/$PROJECT_NAME/$ENV/$PROJECT_VERSION\").apps[].labels.stack_version]|unique \
    | select(.[] != \"$PROJECT_GROUP/$PROJECT_NAME/$ENV/$PROJECT_VERSION\")[]"
}

function deploy_internal_stack {
    dcos marathon group add $MARATHON_TEMP_PATH
}

function wait_until_internal_stack_deployed {
    for i in ${PROJECT_COMPONENTS[@]}; do
        if [ ! $i = $BLUE_GREEN_CONTAINER ]; then
            echo "Waiting until /$PROJECT_GROUP/$PROJECT_NAME/$ENV/$PROJECT_VERSION/$i stack is healthy "
            while [ -z "$(dcos marathon app show /$PROJECT_GROUP/$PROJECT_NAME/$ENV/$PROJECT_VERSION/$i | jq '.tasks[]?.healthCheckResults[]? | select (.alive == true)')" ]
            do
                sleep 1
            done
            echo "/$PROJECT_GROUP/$PROJECT_NAME/$ENV/$PROJECT_VERSION/$i is healthy"
        fi
    done
}

function deploy_blue_green_component {
    if [ ! -z $BLUE_GREEN_CONTAINER ]; then
        ./marathon-lb/zdd.py -j $TEMP_FOLDER/marathon-blue.nginx.json -m $MARATHON_URL -f -l $MARATHON_LB_URL --syslog-socket /dev/null
    fi
}

function delete_old_versions {
    echo "Deleting old version"
    while read p; do $(eval echo dcos marathon group remove ${p}); done <$TEMP_FOLDER/current-version.json
    echo "deploy ended"
}
