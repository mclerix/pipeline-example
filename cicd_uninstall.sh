#!/bin/bash
#####################################################
#
# Uninstall CI/CD tools in Openshift
# Jenkins, Gitlab, Nexus
#
# Made by: Maxime CLERIX
# Date: 27/02/17
#
#####################################################
# Notes:

# DEPENDENCIES:

# TO FIX:
#

# TO ENHANCE
#

# HOW TO RUN THE SCRIPT:
# This script should be executed as root directly on the Openshift Master machine.
# su - cicd_uninstall.sh

##############################################################

oc delete project cicd development test production
oc delete pv gitlab-volume gitlab1-volume gitlab2-volume gitlab3-volume jenkins-volume nexus-volume nexus3-pv
oc delete sa gitlab-ce-user jenkins nexus

oc delete is jenkins -n openshift
oc delete template gitlab-ce -n openshift
oc delete template jenkins-ephemeral -n openshift
oc delete template jenkins-persistent -n openshift

rm -rf /exports/gitlab* /exports/jenkins /exports/nexus
rm -f /etc/origin/example/gitlab-template.json /etc/origin/example/nexus3-resources.json

oadm policy remove-scc-from-user anyuid gitlab-ce-user
oadm policy remove-scc-from-user anyuid nexus

sed '/gitlab/d' /etc/exports.d/openshift-ansible.exports > /etc/exports.d/openshift-ansible.exports
sed '/jenkins/d' /etc/exports.d/openshift-ansible.exports > /etc/exports.d/openshift-ansible.exports
sed '/nexus/d' /etc/exports.d/openshift-ansible.exports > /etc/exports.d/openshift-ansible.exports

exportfs -r
