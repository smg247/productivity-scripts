#!/bin/bash
tmpdir="/tmp"

os=$(uname -s)

if [ "$os" == "Darwin" ]; then
  #There are no prometheus images for darwin so we must fake it for now
  prometheusdir="$tmpdir/prometheus"
  if [ ! -d $prometheusdir ]; then
    echo "creating empty $prometheusdir"
    mkdir $prometheusdir
  fi

  #There are no promtool images for darwin so we must fake it for now
  promtooldir="$tmpdir/promtool"
  if [ ! -d $promtooldir ]; then
    echo "creating empty $promtooldir"
    mkdir $promtooldir
  fi
fi

artifactDir=$tmpdir/artifacts
if [ ! -d $artifactDir ]; then
  echo "creating empty $artifactDir"
  mkdir $artifactDir
fi

echo "Cleaning test cache"
go clean -testcache

echo "removing tmp kubeconfig"
rm -rf $tmpdir/.ci-operator-kubeconfig

echo "Running on context: "
oc config current-context

echo "If a registry credentials issue occurs switch to app.ci context and run 'oc registry login'"

TMPDIR=$tmpdir \
  ARTIFACT_DIR=$artifactDir \
  make local-e2e \
  TESTFLAGS="-run $1" \
  GOTESTSUM_FORMAT=standard-verbose
