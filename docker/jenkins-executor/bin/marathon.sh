#!/bin/bash

SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do # resolve $SOURCE until the file is no longer a symlink
  DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
  SOURCE="$(readlink "$SOURCE")"
  [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE" # if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
done
DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
cd $DIR

[ $# -lt 1 ] && echo "Usage: $0 <deploy|destroy>" && exit 1
command="${1#*=}"
shift

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

if [[ -n "${VERSION+1}" ]]; then
    PROJECT_VERSION=$VERSION
fi

[ -f $DIR/config/env.$ENV ] && source $DIR/config/env.$ENV || exit 1
[ -f $DIR/src/deploy.sh ] && source $DIR/src/deploy.sh || exit 1

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
