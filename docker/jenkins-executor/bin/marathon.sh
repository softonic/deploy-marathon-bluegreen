#!/bin/bash

while [ $# -gt 0 ]; do
  case "$1" in

    -f|--force)
       FORCE_DELETE="--force"
       ;;

    --version=*)
      VERSION="${1#*=}"
      ;;

    --environment=*)
      ENV="${1#*=}"
      ;;
    *)
  esac
  shift
done

if [[ -z ${ENV+x} ]]; then
    ENV=prod
fi
[ -f $WORKSPACE/config/env.$ENV ] && source $WORKSPACE/config/env.$ENV || exit 1
[ -f $WORKSPACE/src/deploy.sh ] && source $WORKSPACE/src/deploy.sh || exit 1

if [[ -n "${VERSION+1}" ]]; then
    PROJECT_VERSION=$VERSION
fi

case ${command} in

    deploy)
        echo "deploying ${PROJECT_GROUP}/${PROJECT_NAME} v$PROJECT_VERSION"
        deploy
    ;;

    destroy)
        read -r -p "Are you sure? [y/N] " response
        if [[ $response =~ ^([yY][eE][sS]|[yY])$ ]]
        then
            dcos marathon group remove /${PROJECT_GROUP}/${PROJECT_NAME}/${PROJECT_VERSION} $FORCE_DELETE
        fi
    ;;

esac
