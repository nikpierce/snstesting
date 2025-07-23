#!/bin/bash

# Exit on any error
set -e

#TODOs
# Check whether the user's account has the right permissions / is in the right groups serverside.
# Check whether server-side folders have the right permissions for GROUP write, including execute on the /home/toolkit directory
# Tag the commit with the deploy environment. Check in. Will that break something if there's other changes on the vine?
# Checkout the tag at the far end, ready for a docker-enabled account to do the rest.
# Check whether the docker-compose directory, and the symlink to the compose file, already exists. Handle if not.

#  vars
REMOTE_SERVER="feeldsparror.cubecinema.com"
TOOLKIT_BASE_DIR="/home/toolkit"

# Get the current commit hash
COMMIT_HASH=$(git rev-parse --short=10 HEAD)

echo '''
This is your current commit:
------------------------------------------------------------------
'''
git log -1 "$COMMIT_HASH"
echo '''
------------------------------------------------------------------
'''

GOOD_OPT=false
while ! $GOOD_OPT; do
    read -p "If you want to deploy the above commit, type an environment name (staging/production) or type 'exit' (or just Ctrl+C) to end without deploying.
    " DEPLOY_ENV

    case $DEPLOY_ENV in
        staging | production | exit)
        GOOD_OPT=true
        ;;
    esac

    if [ "$DEPLOY_ENV" = 'exit' ]; then
        echo 'Laters.'
        exit
    fi

    if ! $GOOD_OPT; then
        echo "We're being quite specific on this one. The response has to match *exactly*."
    fi
done

# for now, create a git archive copy that over, unpack it, then remove the .tgz files
ARCHIVE_FILE="$DEPLOY_ENV"_code_export.tgz
CHECKOUT_DIR="$TOOLKIT_BASE_DIR/checkout/$DEPLOY_ENV"
DOCKER_COMPOSE_DIR="/opt/stacks/toolkit-$DEPLOY_ENV"

git archive --format=tgz -o "$ARCHIVE_FILE" "$COMMIT_HASH"
rsync -avz --delete ./"$ARCHIVE_FILE" "$REMOTE_SERVER:$TOOLKIT_BASE_DIR/tmp"
rm ./"$ARCHIVE_FILE"
# unpack
ssh "$REMOTE_SERVER" "rm -Rf '$CHECKOUT_DIR'/*"
ssh "$REMOTE_SERVER" "tar -xzf '$TOOLKIT_BASE_DIR'/tmp/'$ARCHIVE_FILE' -C '$CHECKOUT_DIR'"

# docker build # TODO: investigate if docker copmpose build makes sense
# add --no-cache to make sure updated filesystems are added, etc. remove to significantly speed up build and create fewer hanging containers
# pass in hardcoded UID of the toolkit user to simplify bind mount things. TODO: If someone wants to make this fancy and dynamic go for it
echo "***************** build $DEPLOY_ENV image *****************"
ssh "$REMOTE_SERVER" "cd '$CHECKOUT_DIR' && docker build --build-arg ENV_NAME=$DEPLOY_ENV --build-arg TOOLKIT_UID=1004 --tag toolkit:'$DEPLOY_ENV' ."

echo "***************** start $DEPLOY_ENV container(s) *****************"
ssh "$REMOTE_SERVER" "cd '$DOCKER_COMPOSE_DIR' && docker compose up --detach"
