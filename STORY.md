# Feuille de route démonstration CICD
## Déploiement
1. Execute cicd.sh script `time ./cicd_deployment_light.sh` or `time ./cicd_deployment.sh` (with PersistentVolumes creation).
> time is not required, it is just to show how fast it is to deploy the whole stack.
2. Log in to the OpenShift web console with the credentials admin_cicd/admin_cicd.
3. Show that CICD stack is being deployed.

## Use Case #1: Demonstrate a pipeline
*Once the script is done and the CICD stack is deployed*

1. Move to "CICD - Environment"
2. Open Gitlab in a new tab, authenticate with credentials dev_redhat/dev_redhat and show that Gitlab has been populated with a project "angulartodo"
3. Go back to OpenShift, navigate to "Builds > Pipelines" and launch the pipeline.
4. Then click on "View Log" to see the pipeline execution. Once the pipeline is launched, explain that Jenkins dynamically deploys a slave in OpenShift to execute the job.
5. During the application build, move to "CICD - Development" project and show the S2I process.
6. Once built, show the application's deployment within "CICD - Development" project.
7. Afterward, go back on the pipeline, and follow it's execution during tests.
  * *(Optional)* During the pipeline, SonarQube runs a scan of the source code to produce a code quality report. If this report is complient with the quality gate, the pipeline executes the next steps, otherwise it fails. <br>
  Open SonarQube and log in (admin/admin). You will end up on the main page of SonarQube. Click on "explore projects", the todo application report will be displayed.
  * *(Optional)* In the Jenkins logs of the Pipeline, you can also see the unit tests executed by Jasmine.
8. *(Optional)* Show Use case #5.
9. On the pipeline screen, you should see the step "Production - Wait for Approval". Click
10. Show that the application is up and running in production. Add some todos to the application. (While redeploying the application later, you should be able to show that the data are separated from the application and that you get the same todos even if you deploy a new version of the application).

## Use Case #2: Demonstrate triggers and webhooks
Gitlab and Openshift Pipeline has been configured with webhooks. Each time that a commit is done on the git repository, it will trigger the pipeline in OpenShift.
1. Go on gitlab and log in with dev_redhat/dev_redhat credentials.
2. Move to dev_redhat/angulartodo repository
3. On the top of the window, click on Repository.
4. Access the file public/index.html, click on "Edit" and for example change the title line 34. Then click on "Commit Changes".
5. Go back on OpenShift, on the pipeline view. You should see that a new build has been automatically triggered. (This build will not start if previous builds are running).
6. Once the application build and deployed you should see the changes in each environment looking at the application.
7. *(Optional)* Show Use Case #3

## Use Case #3: Deployment strategy
*This Use Case is only available after a second execution of the pipeline.*
1. During the 2nd execution of the pipeline, wait for the step "Production - Wait for Approval". Click on "Input Required" under the step. It will open a new tab, split your screen in order to display on the left the new Jenkins window and on the other side the Overview of the "CICD - Production" project.
2. On Jenkins, click on "proceed". It will launch the deployment on the production environment.
3. On the "CICD - Production" project Overview you should graphically see that pods are replaced 1 by 1 by the new pods. (/!\ the pod startup is really quick)

## Use Case #4: Play with unit tests and pipeline
The goal of this use case is to show that the pipeline will be aborted if the unit tests fail.
1. Go on gitlab and log in with dev_redhat/dev_redhat credentials.
2. Move to dev_redhat/angulartodo repository
3. On the top of the window, click on Repository.
4. Access the file spec/app_spec.js, click on "Edit" and for example change the title line 10 and set `expect(true).toBe(false);` instead of `expect(true).toBe(true);` . Then click on "Commit Changes".

```javascript
describe("App", function() {
     it("is creating Todo", function() {
         expect(true).toBe(true);
     });
     it("is deleting Todo", function() {
         expect(true).toBe(true);
     });
     it("is getting Todo", function() {
         expect(true).toBe(false);
     });
});
```
5. On commit, it will launch the pipeline again. At the step 4, it should fail while executing the test and the pipeline should be aborted at the step "Development - Unit Testing".
6. You can click on view Log to access Jenkins Logs. At the end of the log, you should see that the job has failed and that a unit test did not pass.

```js
+ jasmine-node --color --verbose /tmp/workspace/cicd-cicdpipeline/spec

App[33m - 13 ms[0m
[32m    is creating Todo[0m[34m - 7 ms[0m
[32m    is deleting Todo[0m[34m - 1 ms[0m
[31m    is getting Todo[0m[34m - 3 ms[0m

Failures:

  1) App is getting Todo
   Message:
     [31mExpected true to be false.[0m
   Stacktrace:
     Error: Expected true to be false.
    at null.<anonymous> (/tmp/workspace/cicd-cicdpipeline/spec/app_spec.js:10:18)
```

## Use Case #5: Demonstrate quotas
*The pipeline should have been executed at least once*
1. Log in to the web console as user test_cicd/test_cicd
2. Click on the project "CICD - Test"
3. Try to increase the number of pod "myapp" to 3. It should scale in few seconds.
4. Try to increase the number of pod "myapp" to 4. OpenShift will display a Warning message. `Quota limit has been reached. View Quota | Don't show me again`.
5. A quota has been created and limit the number of pods in this project to 4.
6. On the left side click on "Resources > Quota" and you should see all the quotas for this project.

## Use Case #6: Demonstrate RBAC (Roles Based Access Control)
4 users has been created for this demonstration: admin_cicd/admin_cicd, dev_cicd/dev_cicd, test_cicd/test_cicd, production_cicd/production_cicd.
admin_cicd has access to all the CICD projects in OpenShift and can access the CICD Stack. The other accounts only have access to their respective environment.
You can log in with each user to see their different access.
