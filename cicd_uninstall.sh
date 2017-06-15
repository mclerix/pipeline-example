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

oc delete is gitlab-ce gitlab-ce-redis sonatype-nexus3 -n cicd
oc delete is myapp -n development
docker rmi -f $REGISTRY_IP/cicd/nexus3:latest \
              $REGISTRY_IP/development/myapp:latest \
              $REGISTRY_IP/development/myapp:promoteToQA \
              $REGISTRY_IP/development/myapp:promoteToProd
oc delete project cicd development test production
oc delete pv gitlab-volume gitlab1-volume gitlab2-volume gitlab3-volume jenkins-volume sonarqube-pv

rm -rf /exports/gitlab* /exports/jenkins /exports/sonar_mysql
rm -f ./gitlab-template.json ./sonar-template.json

oadm policy remove-scc-from-user anyuid gitlab-ce-user
oadm policy remove-scc-from-user anyuid sonarqube

sed '/gitlab/d' /etc/exports.d/openshift-ansible.exports > /etc/exports.d/openshift-ansible.exports
sed '/jenkins/d' /etc/exports.d/openshift-ansible.exports > /etc/exports.d/openshift-ansible.exports
sed '/sonar/d' /etc/exports.d/openshift-ansible.exports > /etc/exports.d/openshift-ansible.exports

exportfs -r
