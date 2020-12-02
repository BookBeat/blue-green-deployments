# blue-green-deployments at BookBeat

A sample repository of how we implement blue-green deployments using Helm and Kubernetes at [BookBeat](https://www.bookbeat.com/).

The idea is based off https://github.com/puneetsaraswat/HelmCharts/tree/master/blue-green but changed slightly to suit our needs.

What makes this work is the use of selectors in the services and using different tag variables for the two deployments.

## Pre-requisites

* A Kubernetes cluster (tested on AKS and minikube)
* helm
* kubectl
* Powershell (`apt install powershell`)

## Deploy procedure



Implemented in `deploy.ps1`

-  you want to release tag `gandalf` to the cluster
- the deploy script will ask which `productionSlot` is currently being used. Let's say that the current tag `aragorn` is deployed to `green`, then the next slot will be `blue`.
- The deploy script then sets `Values.blue.tag=gandalf` and `stagingSlot=blue` and activates the blue deployment with `blue.enabled=true`.
- As soon as it's up and running a smoke test will be run towards `service-staging` which will verify that the service is up and running.
- The service will be updated with `productionSlot=blue`
- The green deployment will be taken down so we don't have idle pods running in the cluster for no reason

## Deployed infrastructure

- ingress service `ingress.yaml`

  We use `azure/application-gateway` but use whatever suits your environment
- prod service `service.yaml`

  This is what points to the current `productionSlot`
- staging service `service-staging.yaml`

  This points to the release candidate about to be released. This is a good candidate to run UI tests towards.
- deployment `deployment-blue.yaml` or `deployment-green.yaml`
- config map `env.yaml`

  Reads `appsettings.json` which we override with environment variables for each environment per deploy. This is added to the deployment and the sha is set as an annotation which makes it possible to update only the appsettings.json and deploy it to force a re-deploy of the deployments even if the rest of the configuration is the same.

## Contributing

Have any ideas or suggestions of improvements? Contact us at https://www.bookbeat.co.uk/contact
