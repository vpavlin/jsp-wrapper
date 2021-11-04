# jsp-wrapper

This repo serves as a build wrapper for https://github.com/opendatahub-io/jupyterhub-singleuser-profiles to speed up the development.

Both methods described below require every change to be pushed to your fork of jupyterhub-singleuser-profiles repo so that the [Dockerfile](/Dockerfile) can install from there. 

## Configuration

You can set these options in a local `.env.local` file:
```
QUAY_REPO=<your quay repo user name> # a system user is used by default
GIT_USER=<your github user name> # a system user is used by default
NAMESPACE=<applications namespace>  # default 'odh-ods-operator', set to 'odh-redhat-ods-applications' for downstream
OPERATOR_NAME=<operator name> # default 'odh-operator', set to 'rhods-operator' for downstream
OPERATOR_NAMESPACE=<operator name> # default 'odh-ods-operator', set to 'redhat-ods-operator' for downstream
GIT_REF=<your github jsp branch to deploy>
LOCAL_CMD=<podman | docker> # default 'podman'

ADMIN_NAME ?= <admin username> # default 'odhadmin'
ADMIN_PASS ?= <admin password> # default 'odhadmin' 
ADMIN_GROUP ?= <admin-group> # default 'odh-admins', set to 'rhods-admins' for downstream

USER_NAME ?= <user username> # default 'odhuser'
USER_PASS ?= <user password> # default 'odhuser' 
USER_GROUP ?= <user-group> # default 'odh-users', set to 'rhods-users' for downstream
```

## Build locally

```
make
```

The above command will

1. Update the ImageStream in the cluster to point to your custom image on Quay.io
2. Build using podman or docker
3. Tag and push the result to `quay.io/$USER/jupyterhub-img:test-jsp`
4. Import the new image in your cluster
5. Scale down the operator, if necessary (preventing auto re-deploy)
6. Start a rollout of new version


## Build remotely

```
make remote
```

The above command will

1. Create a new BuildConfig for your build
2. Kick off the build with log watch
3. Scale down the operator, if necessary (preventing auto re-deploy)
4. Start a rollout of new version

## Build with specific jupyterhub-odh branch

```
make remote-odh
```

The above command will

1. Create two BuildConfigs (one for adding JH-ODH to the base image, second for adding JSP)
2. Kick off each build in succession
3. Start rollout of the new version

### Variables

* `JH_ODH_REPO` - Name of the jupyterhub-odh repo
* `JH_ODH_REF` - Git branch of jupyterhub-odh

## Create Users

```
make users
```

The above command will

1. Create the cluster OAuth if necessary
2. Create a `ADMIN_NAME` user with `ADMIN_PASS` password
3. Add `ADMIN_NAME` to the OAuth
4. Add `ADMIN_NAME` to the `ADMIN_GROUP`
5. Create a cluster admin role binding for `ADMIN_NAME`
7. Create a `USER_NAME` user with `USER_PASS` password
8. Add `USER_NAME` to the OAuth
9. Add `USER_NAME` to the `USER_GROUP`
10. Create a namespaced basic user role binding for the `USER_NAME`
11. Grant view privilege for `USER_NAME` for project `NAMESPACE`