# Purpose of pipeline-example repository
Demonstrate CICD pipeline in Openshift. This demonstration includes the following cases:
* Jenkins pipeline
  * Build
  * Deployment
  * Unit testing
  * Static Code Analysis
  * Promotion
  * Approval
* Pipeline Webhook
* Authorizations
* Resources Quotas
* Autoscaling

# CI/CD Stack
The CI/CD tools used in this demonstration are:
* **Jenkins** - Automation server
* **Nexus** - Repository
* **Gitlab** - Source code management
* **SonarQube** - Static code analysis

# Prerequisites

* Have an OpenShift instance running. This could be :
  * OpenShift Container Platform
  * OpenShift Origin
  * Minishift
* Git installed
* Openshift User Accounts created: admin_cicd, dev_cicd, test_cicd, production_cicd.
* Persistent volumes created:
  * gitlab-volume
  * gitlab1-volume
  * gitlab2-volume
  * gitlab3-volume
  * jenkins-volume
  * nexus3-pv
  * sonarqube-pv

# Docker Images used in this demonstration
The images below are used in this demonstration. In order to speed up the deployment of this demonstration it is advised to import the images before. <br>
**gitlab/gitlab-ce** [https://hub.docker.com/r/gitlab/gitlab-ce/] <br>
**rhscl/postgresql-94-rhel7** [https://access.redhat.com/containers/#/registry.access.redhat.com/rhscl/postgresql-94-rhel7] <br>
**rhscl/mysql-56-rhel7** [https://access.redhat.com/containers/#/registry.access.redhat.com/rhscl/mysql-57-rhel7] <br>
**docker.io/sonarqube:6.3** [https://hub.docker.com/_/sonarqube/] <br>
**openshift3/jenkins-2-rhel7** (Already imported while OCP installed) <br>

# How to run the demonstration
1. Connect to your Openshift Master as system:admin. <br>
``oc login -u system:admin``
2. Clone this repository <br>
``git clone https://github.com/clerixmaxime/pipeline-example.git``
3. Execute cicd_deployment_light.sh. The script will deploy the whole CI/CD stack, configure the environments, populate Gitlab and create the pipeline. <br>
``bash cicd_deployment_light.sh`` ou ``./cicd_deployment_light.sh``
4. The demonstration should be up with the whole CI/CD stack running in the project cicd and 3 environments development, test and production created.

# What to demonstrate?
## Jenkins pipeline

## Webhook

## Quotas

## Authorizations

## Autoscaling
