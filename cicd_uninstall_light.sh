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

oadm policy remove-scc-from-user anyuid gitlab-ce-user
oadm policy remove-scc-from-user anyuid nexus
oadm policy remove-scc-from-user anyuid sonarqube
