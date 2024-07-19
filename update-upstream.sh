#!/bin/bash

cd "/Users/sgoeddel/projects/$1"

branch=`git rev-parse --abbrev-ref HEAD`

master=`git branch -l main master --format '%(refname:short)'`

echo "checking out $master in:"
pwd
git checkout $master

echo fetching upstream
git fetch upstream

echo merging upstream
git merge upstream/$master

echo pushing
git push origin $master

echo "checking out $branch"
git checkout $branch
