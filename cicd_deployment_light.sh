#!/bin/bash
#####################################################
#
# Deployment of CI/CD tools in Openshift
# Jenkins, Gitlab, SonarQube
#
# Made by: Maxime CLERIX
# Date: 27/02/17
#
#####################################################
# Notes:

# PREREQUISITES:
# Create the following users on your Openshift Cluster: admin_cicd, dev_cicd, test_cicd & production_cicd
# HOW TO RUN THE SCRIPT:
# This script should be executed as root directly on the Openshift Master machine.
# su - cicd_deployment.sh

############ VARIABLES ############
# CICD project definition
PROJECT_NAME="cicd"
PROJECT_DISPLAY_NAME="CI/CD Environment"
PROJECT_DESCRIPTION="CI/CD Environment using Jenkins, Gitlab and SonarQube"
# Cluster-related
SUB_DOMAIN="cloudapps01.openhybridcloud.io"
# CICD stack definition
GITLAB_APPLICATION_HOSTNAME="gitlab.$SUB_DOMAIN"
GITLAB_ROOT_PASSWORD="gitlab123"
SONARQUBE_APPLICATION_HOSTNAME="sonarqube.$SUB_DOMAIN"
PIPELINE_URL="https://raw.githubusercontent.com/clerixmaxime/pipeline-example/master/pipeline-definition.yml"
REFERENCE_APPLICATION_NAME="angulartodo"
REFERENCE_APPLICATION_IMPORT_URL="https://github.com/clerixmaxime/node-todo.git"
USER_NAME="dev_redhat"
USER_USERNAME="dev_redhat"
USER_MAIL="dev@redhat.com"
USER_PASSWORD="dev_redhat"
# Checking deployment configuration
DEPLOYMENT_CHECK_INTERVAL=10 # Time in seconds between each check
DEPLOYMENT_CHECK_TIMES=120 # Total number of check

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

  oc new-project $PROJECT_NAME \
    --display-name="$PROJECT_DISPLAY_NAME" \
    --description="$PROJECT_DESCRIPTION"

  echo
  echo "$PROJECT_NAME Project created."
  echo

  echo "SETUP rights for the project: $PROJECT_NAME"
  oadm policy add-scc-to-group anyuid system:serviceaccounts:$PROJECT_NAME

  do_jenkins
}

function do_jenkins() {

  oc new-app jenkins-persistent -n $PROJECT_NAME
  echo "--> Deploying Jenkins on Openshift $PROJECT_NAME"

  do_sonarqube
}

function do_sonarqube() {

  echo "--> Dowloading SonarQube template"
  wget https://raw.githubusercontent.com/clerixmaxime/pipeline-example/master/sonarqube-template.yml -O ./sonar-template.yml
  echo "--> Importing SonarQube template"
  oc create -f ./sonar-template.yml -n $PROJECT_NAME
  echo "--> SonarQube template imported"

  echo "--> Updating SonarQube serviceaccount authrizations"
  oadm policy add-scc-to-user anyuid -z sonarqube -n $PROJECT_NAME
  echo "--> SonarQube serviceaccount authrizations updated"


  oc new-app sonarqube \
    -p APPLICATION_HOSTNAME=$SONARQUBE_APPLICATION_HOSTNAME \
    -n $PROJECT_NAME
  echo "--> Deploying SonarQube on Openshift"
  echo "--> Default credentials for SonarQube: admin/admin"

  do_gitlab
}

function do_gitlab() {
  echo "--> Starting Gitlab deployment"
  # Download Gitlab template for Openshift
  echo "--> Dowloading Gitlab template"
  # With latest template versions
  # wget https://gitlab.com/gitlab-org/omnibus-gitlab/raw/master/docker/openshift-template.json -O ./gitlab-template.json
  wget https://gitlab.com/gitlab-org/omnibus-gitlab/raw/c025ff897de5819b21f479dcee8d32e17295ddf4/docker/openshift-template.json -O ./gitlab-template.json
  # Import Gitlab Template
  echo "--> Importing Gitlab template"
  oc create -f ./gitlab-template.json -n $PROJECT_NAME
  echo "--> Gitlab template imported"

  # In order to run Gitlab, you should ensure that the gitlab-ce-user serviceaccount has the right authorizations.
  # Add it to the anyuid security context
  echo "--> Updating gitlab-ce-user serviceaccount authrizations"
  oadm policy add-scc-to-user anyuid -z gitlab-ce-user -n $PROJECT_NAME
  echo "--> gitlab-ce-user serviceaccount authrizations updated"

  # Deploy Gitlab
  oc new-app gitlab-ce \
    -p APPLICATION_HOSTNAME=$GITLAB_APPLICATION_HOSTNAME \
    -p GITLAB_ROOT_PASSWORD=$GITLAB_ROOT_PASSWORD \
    -n $PROJECT_NAME
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
  oc create -f $PIPELINE_URL -n $PROJECT_NAME

  # Instantiate the environments
  #  --> Project development
  oc new-project development --display-name="CICD - Development"
  oadm policy add-role-to-user edit system:serviceaccount:$PROJECT_NAME:jenkins -n development
  #  Create database for dev environment
  oc new-app mongodb-ephemeral \
    -p MONGODB_USER=mongo \
    -p MONGODB_PASSWORD=mongo \
    -p MONGODB_ADMIN_PASSWORD=mongo \
    -p MONGODB_DATABASE=mongo \
    -p DATABASE_SERVICE_NAME=mongo-todo \
    -n development

  #  --> Project test
  oc new-project test --display-name="CICD - Test"
  oadm policy add-role-to-user edit system:serviceaccount:$PROJECT_NAME:jenkins -n test
  oadm policy add-role-to-group system:image-puller system:serviceaccounts:test -n development
  #  Create database for test environment
  oc new-app mongodb-ephemeral \
    -p MONGODB_USER=mongo \
    -p MONGODB_PASSWORD=mongo \
    -p MONGODB_ADMIN_PASSWORD=mongo \
    -p MONGODB_DATABASE=mongo \
    -p DATABASE_SERVICE_NAME=mongo-todo \
    -n test

  #  --> Project production
  oc new-project production --display-name="CICD - Production"
  oadm policy add-role-to-user edit system:serviceaccount:$PROJECT_NAME:jenkins -n production
  oadm policy add-role-to-group system:image-puller system:serviceaccounts:production -n development
  #  Create database for production environment
  oc new-app mongodb-ephemeral \
    -p MONGODB_USER=mongo \
    -p MONGODB_PASSWORD=mongo \
    -p MONGODB_ADMIN_PASSWORD=mongo \
    -p MONGODB_DATABASE=mongo \
    -p DATABASE_SERVICE_NAME=mongo-todo \
    -n production

  # Deploy the test and production objects
  oc new-app https://raw.githubusercontent.com/clerixmaxime/pipeline-example/master/env-template.yml \
    -p NAMESPACE="test" \
    -p APP_IMAGE_TAG="promoteToQA" \
    -p HOSTNAME=myapp-test.$SUB_DOMAIN \
    -p POD_LIMITATION="4" \
    -n test

  oc new-app https://raw.githubusercontent.com/clerixmaxime/pipeline-example/master/env-template.yml \
    -p NAMESPACE="production" \
    -p APP_IMAGE_TAG="promoteToProd" \
    -p HOSTNAME=myapp.$SUB_DOMAIN \
    -p POD_LIMITATION="20" \
    -n production

  # Deploy reference application
  oc new-app https://raw.githubusercontent.com/clerixmaxime/pipeline-example/master/generic-cicd-template.yml \
    -p APP_SOURCE_URL=http://gitlab.cloudapps.example.com/$USER_USERNAME/$REFERENCE_APPLICATION_NAME.git \
    -p SUB_DOMAIN=$SUB_DOMAIN \
    -n development

  # Set policyBindings for CICD users
  # Admin right
  oadm policy add-role-to-user admin admin_cicd -n cicd
  oadm policy add-role-to-user admin admin_cicd -n development
  oadm policy add-role-to-user admin admin_cicd -n test
  oadm policy add-role-to-user admin admin_cicd -n production
  # Environements' users rights
  oadm policy add-role-to-user admin dev_cicd -n development
  oadm policy add-role-to-user admin test_cicd -n test
  oadm policy add-role-to-user admin production_cicd -n production

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
