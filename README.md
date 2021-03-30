# jsp-wrapper

This repo serves as a build wrapper for https://github.com/opendatahub-io/jupyterhub-singleuser-profiles to speed up the development.

Both methods described below require every change to be pushed to your fork of jupyterhub-singleuser-profiles repo so that the [Dockerfile](/Dockerfile) can install from there. 

## Build locally

```
make
```

The above command will

1. Update the ImageStream in the cluster to point to your custom image on Quay.io
2. Build using podman
3. Tag and push the result to `quay.io/$USER/jupyterhub-img:test-jsp`
4. Import the new image in your cluster
5. Start a rollout of new version


## Build remotely

```
make remote
```

The above command will

1. Create a new BuildConfig for your build
2. Kick off the build with log watch
3. Start a rollout of new version

## Configuration

You can change these options

* `USER` - a system user is used by default, will be used for GH user and Quay.io user
* `NAMESPACE` - the OpenShift namespace where ODH is deployed
* `GIT_REF` - Git reference where your code lives (only needed for remote builds)