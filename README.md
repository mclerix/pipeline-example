**/!\ This file should be updated**

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
* Autoscaling (Under construction)

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
```bash
git clone https://github.com/clerixmaxime/pipeline-example.git
cd ./pipeline-example
git branch angular-todo
```
3. **/!\ Currently, the definition of the pipeline does not use variable. You should verify that the application sub_domain of your Openshift match the one defined in the jenkins file for Gitlab URL line 43 and 53 in pipeline-definition.yml. If it is not the case, make a copy of this file, put it online on your own git (fork this repository) and modify the value to match your Openshift configuration. In cicd_deployment.sh or cicd_deployment_light.sh mofidy the line 33 to add the right PIPELINE_URL.**
4. Execute cicd_deployment_light.sh. The script will deploy the whole CI/CD stack, configure the environments, populate Gitlab and create the pipeline. <br>
``bash cicd_deployment_light.sh`` ou ``./cicd_deployment_light.sh`` <br>
5. The demonstration should be up with the whole CI/CD stack running in the project cicd and 3 environments development, test and production created.

# What to demonstrate?
refers to `STORY.md` file
