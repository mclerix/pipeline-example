#!/bin/bash
#####################################################
#
# Uninstall CI/CD tools in Openshift
# Jenkins, Gitlab, Nexus
#
# Made by: Maxime CLERIX
# Date: 27/02/17
#
##############################################################
REGISTRY_IP=172.30.253.239:5000
##############################################################

oc delete is gitlab-ce gitlab-ce-redis nexus3 sonatype-nexus3 -n cicd
oc delete is myapp -n development
docker rmi -f $REGISTRY_IP/cicd/nexus3:latest \
              $REGISTRY_IP/development/myapp:latest \
              $REGISTRY_IP/development/myapp:promoteToQA \
              $REGISTRY_IP/development/myapp:promoteToProd
oc delete project cicd development test production

oadm policy remove-scc-from-user anyuid gitlab-ce-user
oadm policy remove-scc-from-user anyuid nexus
oadm policy remove-scc-from-user anyuid sonarqube
