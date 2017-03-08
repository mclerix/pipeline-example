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
#TECHNOLOGY=""
#METHODOLOGY=""
SUB_DOMAIN="cloudapps.example.com"
# CI/CD deployment related
GITLAB_APPLICATION_HOSTNAME="gitlab.$SUB_DOMAIN"
GITLAB_ROOT_PASSWORD="gitlab123"
NEXUS_APPLICATION_HOSTNAME="nexus.$SUB_DOMAIN"
NEXUS_VOLUME_SIZE="5Gi"
PIPELINE_URL="https://raw.githubusercontent.com/clerixmaxime/pipeline-example/master/pipeline-definition.yml"
# Checking deployment configuration
DEPLOYMENT_CHECK_INTERVAL=10 # Time in seconds between each check
DEPLOYMENT_CHECK_TIMES=60 # Total number of check
# Gitlab population related
REFERENCE_APPLICATION_NAME="bgdemo"
REFERENCE_APPLICATION_IMPORT_URL="https://github.com/clerixmaxime/bgdemo"
USER_NAME="demo_redhat"
USER_USERNAME="demo_redhat"
USER_MAIL="demo@redhat.com"
USER_PASSWORD="demo_redhat"

###################################
function wait_for_application_deployment() {

    DC_NAME=$1 # the name of the deploymentConfig, transmitted as 1st parameter
    DEPLOYMENT_VERSION=
    RC_NAME=
    COUNTER=0

    # Validate Deployment is Active
    while [ ${COUNTER} -lt $DEPLOYMENT_CHECK_TIMES ]
    do

        DEPLOYMENT_VERSION=$(oc get -n ${PROJECT_NAME} dc ${DC_NAME} --template='{{ .status.latestVersion }}')

        RC_NAME="${DC_NAME}-${DEPLOYMENT_VERSION}"

        if [ "${DEPLOYMENT_VERSION}" == "1" ]; then
          break
        fi

        if [ $COUNTER -lt $DEPLOYMENT_CHECK_TIMES ]; then
            COUNTER=$(( $COUNTER + 1 ))
        fi

        if [ $COUNTER -eq $DEPLOYMENT_CHECK_TIMES ]; then
          echo "Max Validation Attempts Exceeded. Failed Verifying Application Deployment..."
          exit 1
        fi
        sleep $DEPLOYMENT_CHECK_INTERVAL

     done

     COUNTER=0

     # Validate Deployment Complete
     while [ ${COUNTER} -lt $DEPLOYMENT_CHECK_TIMES ]
     do

         DEPLOYMENT_STATUS=$(oc get -n ${PROJECT_NAME} rc/${RC_NAME} --template '{{ index .metadata.annotations "openshift.io/deployment.phase" }}')

         if [ ${DEPLOYMENT_STATUS} == "Complete" ]; then
           break
         elif [ ${DEPLOYMENT_STATUS} == "Failed" ]; then
             echo "Deployment Failed!"
             exit 1
         fi

         if [ $COUNTER -lt $DEPLOYMENT_CHECK_TIMES ]; then
             COUNTER=$(( $COUNTER + 1 ))
         fi


         if [ $COUNTER -eq $DEPLOYMENT_CHECK_TIMES ]; then
           echo "Max Validation Attempts Exceeded. Failed Verifying Application Deployment..."
           exit 1
         fi

         sleep $DEPLOYMENT_CHECK_INTERVAL

      done

}

function do_OCP_setup () {
  oc login -u system:admin
  oc new-project $PROJECT_NAME --display-name="$PROJECT_DISPLAY_NAME" --description="$PROJECT_DESCRIPTION"
  echo
  echo "$PROJECT_NAME Project created."
  echo

  do_jenkins
}

function do_jenkins() {
  # Deploy Jenkins using jenkins-persistent template
  oc new-app jenkins-persistent -n $PROJECT_NAME
  echo "--> Deploying Jenkins in Openshift project: $PROJECT_NAME"

  do_nexus
}

function do_nexus() {
  echo "--> Dowloading Gitlab template"
  wget https://raw.githubusercontent.com/clerixmaxime/nexus-ose/master/nexus/ose3/nexus3-resources.json -O /etc/origin/examples/nexus3-resources.json
  echo "--> Replacing ci namespace with PROJECT namespace within nexus template"
  sed -i "s/ci/$PROJECT_NAME/g" /etc/origin/examples/nexus3-resources.json
  echo "--> Importing Nexus template"
  oc create -f /etc/origin/examples/nexus3-resources.json -n $PROJECT_NAME
  echo "--> Nexus template imported"

  echo "--> Updating nexus serviceaccount authrizations"
  oadm policy add-scc-to-user anyuid -z nexus -n $PROJECT_NAME
  echo "--> nexus serviceaccount authrizations updated"

  oc new-app nexus3-persistent -p APPLICATION_HOSTNAME=$NEXUS_APPLICATION_HOSTNAME -p SIZE=$NEXUS_VOLUME_SIZE -n $PROJECT_NAME
  echo "--> Deploying Nexus on Openshift"
  echo "#################################################"
  echo "# Default credentials for Nexus: admin/admin123 #"
  echo "#################################################"

  do_gitlab
}

function do_gitlab() {
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

  wait_for_application_deployment "gitlab-ce"
  do_populate_gitlab
}

function do_populate_gitlab() {
  # GET root private token in order to create a new user
  ROOT_PRIVATE_TOKEN=$(curl http://$(echo "$GITLAB_APPLICATION_HOSTNAME")/api/v3/session --data "login=root&password=$(echo "$GITLAB_ROOT_PASSWORD")" | python -c "import sys, json; print json.load(sys.stdin)['private_token']")

  # Create a user that will hold the reference application
  curl --header "PRIVATE-TOKEN: $(echo "$ROOT_PRIVATE_TOKEN")" --data "email=$(echo "$USER_MAIL")&username=$(echo "$USER_USERNAME")&name=$(echo "$USER_NAME")&password=$(echo "$USER_PASSWORD")" http://$(echo "$GITLAB_APPLICATION_HOSTNAME")/api/v3/users
  PRIVATE_TOKEN=$(curl http://$(echo "$GITLAB_APPLICATION_HOSTNAME")/api/v3/session --data "login=$(echo "$USER_USERNAME")&password=$(echo "$USER_PASSWORD")" | python -c "import sys, json; print json.load(sys.stdin)['private_token']")

  # Create the project for the reference application
  curl --header "PRIVATE-TOKEN: $(echo "$PRIVATE_TOKEN")" --data "name=$(echo "$REFERENCE_APPLICATION_NAME")&import_url=$(echo "$REFERENCE_APPLICATION_IMPORT_URL")&public=true" http://$(echo "$GITLAB_APPLICATION_HOSTNAME")/api/v3/projects

  do_deploy_pipeline
}

function do_deploy_pipeline() {
  # Create the pipeline
  oc create -f $PIPELINE_URL -n cicd

  # Instantiate the environments
  #  --> Project development
  oc new-project development
  oadm policy add-role-to-user edit system:serviceaccount:cicd:jenkins -n development
  #  --> Project test
  oc new-project test
  oadm policy add-role-to-user edit system:serviceaccount:cicd:jenkins -n test
  oadm policy add-role-to-group system:image-puller system:serviceaccounts:test -n development
  #  --> Project production
  oc new-project production
  oadm policy add-role-to-user edit system:serviceaccount:cicd:jenkins -n production
  oadm policy add-role-to-group system:image-puller system:serviceaccounts:production -n development

  # Deploy the test and production objects
  oc create -f https://raw.githubusercontent.com/clerixmaxime/pipeline-example/master/testing/testing-dc.yml -n test
  oc create -f https://raw.githubusercontent.com/clerixmaxime/pipeline-example/master/testing/testing-svc.yml -n test
  oc create -f https://raw.githubusercontent.com/clerixmaxime/pipeline-example/master/testing/testing-route.yml -n test
  oc create -f https://raw.githubusercontent.com/clerixmaxime/pipeline-example/master/production/production-dc.yml -n production
  oc create -f https://raw.githubusercontent.com/clerixmaxime/pipeline-example/master/production/production-svc.yml -n production
  oc create -f https://raw.githubusercontent.com/clerixmaxime/pipeline-example/master/production/production-route.yml -n production

  # Deploy reference application
  oc create -f https://raw.githubusercontent.com/clerixmaxime/pipeline-example/master/generic-cicd-template.json -n openshift
  oc new-app generic-app-template -n development

  do_add_webhook
}

function do_add_webhook() {

  if hash jq 2>/dev/null; then
    echo "jq already installed. Ready to add hook."
  else
    # Install jq json parsing tool
    echo "installing jq."
    wget http://stedolan.github.io/jq/download/linux64/jq
    chmod +x ./jq
    cp ./jq /usr/bin
  fi

  WEBHOOK_URL=$(oc describe bc cicdpipeline -n $PROJECT_NAME | grep URL | grep generic | cut -d':' -f2-4)

  PRIVATE_TOKEN=$(curl http://$(echo "$GITLAB_APPLICATION_HOSTNAME")/api/v3/session --data "login=$(echo "$USER_USERNAME")&password=$(echo "$USER_PASSWORD")" | python -c "import sys, json; print json.load(sys.stdin)['private_token']")

  PROJECT_ID=$(curl --header "PRIVATE-TOKEN: $(echo "$PRIVATE_TOKEN")" \
  http://$(echo "$GITLAB_APPLICATION_HOSTNAME")/api/v3/projects?search=$(echo "$REFERENCE_APPLICATION_NAME") | jq '.[0].id')

  curl http://$(echo "$GITLAB_APPLICATION_HOSTNAME")/api/v3/projects/$(echo "$PROJECT_ID")/hooks \
  --header "PRIVATE-TOKEN: $(echo "$PRIVATE_TOKEN")" \
  --data "url=$(echo "$WEBHOOK_URL")&push_events=true&enable_ssl_verification=false"
}

# Test if oc CLI is available
if hash oc 2>/dev/null; then
  do_OCP_setup
else
  echo "the OC CLI is not available on your system. Please install OC to run this script."
  exit 1
fi
