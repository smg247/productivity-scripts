#!/bin/bash

BASE_DIR=~/Projects
NOW=$(date '+%Y%m%d%H%M%S')
echo "updating vendors: commits will be as of $NOW"
echo note that any build failures will need to be dealt with manually and commited

for REPO in "ci-tools" "ci-chat-bot" "release-controller"
do
  cd "$BASE_DIR/$REPO"
  echo updating vendors in:
  pwd

  git checkout master
  git checkout -b update-vendors-$NOW
  go get k8s.io/test-infra

  if [[ $REPO = "ci-tools" ]]
  then
    make update-vendor
  else
    go mod tidy && go mod vendor
  fi

  git add vendor/
  git commit -am"updating vendors at $NOW"
  git push --set-upstream origin update-vendors-$NOW
  git checkout master
done
