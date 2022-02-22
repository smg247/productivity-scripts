#!/bin/bash

for i in "$@"; do
  case $i in
    --server=*)
      server="${i#*=}"
      shift # past argument=value
      ;;
    --token=*)
      token="${i#*=}"
      shift # past argument=value
      ;;
    --cluster=*)
      cluster="${i#*=}"
      shift # past argument=value
      ;;
  esac
done

oc login --token=$token --server=$server
original_cluster_name=`oc config current-context`

oc config delete-context $cluster

oc config rename-context $original_cluster_name $cluster
