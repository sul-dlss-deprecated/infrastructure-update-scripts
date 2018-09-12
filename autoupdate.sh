#!/bin/bash

cd $TMPDIR
mkdir -p $TMPDIR/.autoupdate
cd $TMPDIR/.autoupdate
listOfProjects="argo
assembly
common-accessioning
dor-scripts
dor-services-app
dor_indexing_app
dor-fetcher-service
editstore-updater
etd-robots
gis-robot-suite
goobi-robot
hydra_etd
hydrus
item-release
modsulator-app
modsulator-app-rails
pre-assembly
robot-master
sul-pub
sdr-services-app
was-registrar
was_robot_suite
was-thumbnail-service
workflow-archiver-job"

for i in $listOfProjects; do
  echo $i
  cd $TMPDIR/.autoupdate
  git clone git@github.com:sul-dlss/$i
  cd $i
  git fetch origin
  git checkout -B update-dependencies
  git reset --hard  origin/master
  bundle update &&
  git add Gemfile.lock &&
  git commit -m "Update dependencies" &&
  git push origin update-dependencies &&
  hub pull-request -f -m "Update dependencies"
done
