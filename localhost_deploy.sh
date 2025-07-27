#!/bin/bash

# localhost build of toolkit for devving.

## TODO:
#toolkit_dev_app  | WARNINGS:
#toolkit_dev_app  | wagtailcore.WorkflowState: (models.W036) MariaDB does not support unique constraints with conditions.
#toolkit_dev_app  |      HINT: A constraint won't be created. Silence this warning if you don't care about it.
## TODO: Check whether the django log file is needed in dev. Find a way through the permissions to re-enable it.
## TODO:
# sudo chown $USER:$USER ./var/docker-entrypoint-initdb.d
# rsync -avz feeldsparror.cubecinema.com:/opt/stacks/toolkit-staging/data/docker-entrypoint-initdb.d/* ./var/docker-entrypoint-initdb.d
# rsync -avz feeldsparror.cubecinema.com:/opt/stacks/toolkit-staging/data/media/diary/* ./media/diary/
## TODO: sort/refactor the var directory 
## TODO: add runtests to build pipeline


# Exit on any error
set -e

#  vars
PASSCODE=monkey 

GOOD_OPT=false
while ! $GOOD_OPT; do
    read -p "To build a local version of the toolkit using your system's docker install, type in the following passcode (or \"exit\" or Ctrl+C to end without deploying).

    $PASSCODE
    
    " PASSCODE_ATTEMPT

    case $PASSCODE_ATTEMPT in
        "$PASSCODE" )
        GOOD_OPT=true
        ;;

        exit)
        echo 'Laters.'
        exit
        ;;
    esac

    if ! $GOOD_OPT; then
        echo "That didn't *exactly* match \"$PASSCODE\" or \"exit\"."
    fi
done

DEPLOY_ENV=dev

# create a symbolic link for settings.py. This shouldn't get checked in anywhere.
if [ -L ./toolkit/settings.py ]; then
    rm ./toolkit/settings.py
fi

ln -s ./settings_"${DEPLOY_ENV}".py ./toolkit/settings.py

# docker build # TODO: investigate if docker copmpose build makes sense
# add --no-cache to make sure updated filesystems are added, etc. remove to significantly speed up build.
# pass in the $UID of the current user to re-use as internal uid, for bind mounts
docker build --build-arg ENV_NAME="$DEPLOY_ENV" --build-arg TOOLKIT_UID="$UID" --tag toolkit:"$DEPLOY_ENV" .

# --detach
docker compose -f ./docker-compose-"$DEPLOY_ENV".yml up
