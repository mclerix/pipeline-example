#!/bin/bash
#####################################################
#
# Deployment of CI/CD tools in Openshift
# Jenkins, Gitlab, Nexus
#
# Made by: Maxime CLERIX
# Date: 27/02/17
#
#####################################################
# Notes:

# HOW TO RUN THE SCRIPT:
# This script should be executed as root directly on the Openshift Master machine.
# su - cicd_deployment_light.sh

############ VARIABLES ############

PROJECT_NAME="cicd"
PROJECT_DISPLAY_NAME="CI/CD Environment"
PROJECT_DESCRIPTION="CI/CD Environment using Jenkins, Gitlab and Nexus"
TECHNOLOGY="PHP"
METHODOLOGY=""
#
GITLAB_APPLICATION_HOSTNAME="gitlab.cloudapps.example.com"
GITLAB_ROOT_PASSWORD="gitlab"
NEXUS_APPLICATION_HOSTNAME="nexus.cloudapps.example.com"
NEXUS_VOLUME_SIZE="5Gi"

###################################

# Test if oc CLI is available
if hash oc 2>/dev/null; then

  ############ OPENSHIFT ENVIRONMENT SETUP ############
  # Connect to the Openshift master
  oc login -u system:admin
  # Create a new Openshift project for CI/CD tools
  oc new-project $PROJECT_NAME --display-name=$PROJECT_DISPLAY_NAME --description=$PROJECT_DESCRIPTION

  ############ JENKINS DEPLOYMENT ############

  # Deploy Jenkins using jenkins-persistent template
  oc new-app jenkins-persistent -n $PROJECT_NAME
  echo "--> Deploying Jenkins on Openshift $PROJECT_NAME"

  ############ GITLAB DEPLOYMENT ############

  echo "--> Starting Gitlab deployment"
  # Download Gitlab template for Openshift
  echo "--> Dowloading Gitlab template"
  wget https://gitlab.com/gitlab-org/omnibus-gitlab/raw/master/docker/openshift-template.json -O /etc/origin/examples/gitlab-template.json
  # Import Gitlab Template
  echo "--> Importing Gitlab template"
  oc create -f /etc/origin/examples/gitlab-template.json -n openshift
  echo "--> Gitlab template imported"

  # In order to run Gitlab, you should ensure that the gitlab-ce-user serviceaccount has the right authorizations.
  # Add it to the anyuid security context
  echo "--> Updating gitlab-ce-user serviceaccount authrizations"
  oadm policy add-scc-to-user anyuid -z gitlab-ce-user -n $PROJECT_NAME
  echo "--> gitlab-ce-user serviceaccount authrizations updated"

  # Deploy Gitlab
  oc new-app gitlab-ce -n $PROJECT_NAME -p APPLICATION_HOSTNAME=$GITLAB_APPLICATION_HOSTNAME -p GITLAB_ROOT_PASSWORD=$GITLAB_ROOT_PASSWORD
  echo "--> Deploying Gitlab on Openshift"

  ############ NEXUS DEPLOYMENT ############

  echo "--> Dowloading Gitlab template"
  wget https://raw.githubusercontent.com/clerixmaxime/nexus-ose/master/nexus/ose3/nexus3-resources.json -O /etc/origin/examples/nexus3-resources.json
  echo "--> Replacing ci namespace with cicd namespace within nexus template"
  sed -i "s/ci/$PROJECT_NAME/g" /etc/origin/examples/nexus3-resources.json
  echo "--> Importing Gitlab template"
  oc create -f /etc/origin/examples/nexus3-resources.json -n $PROJECT_NAME
  echo "--> Gitlab template imported"

  echo "--> Updating nexus serviceaccount authrizations"
  oadm policy add-scc-to-user anyuid -z nexus -n $PROJECT_NAME
  echo "--> nexus serviceaccount authrizations updated"

  oc new-app nexus3-persistent -p APPLICATION_HOSTNAME=$NEXUS_APPLICATION_HOSTNAME -p SIZE=$NEXUS_VOLUME_SIZE -n $PROJECT_NAME
  echo "--> Deploying Nexus on Openshift"
  echo "--> Default credentials for Nexus: admin/admin123"
  echo "--> CI/CD Environment deployed"

  ##############################################################
else
  echo "the OC CLI is not available on your system. Please install OC to run this script."
  exit 1
fi
