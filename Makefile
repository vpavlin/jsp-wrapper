QUAY_REPO=$(USER)
IMAGE_NAME=jupyterhub-img
IMAGE_TAG=test-jsp
NAMESPACE ?= $(USER)-odh
GIT_REF ?= master
GIT_USER ?= $(USER)
KFCTL ?= kfctl1.2
GIT_REPO ?= jupyterhub-singleuser-profiles
DOCKERFILE ?= Dockerfile
JH_ODH_REPO ?= jupyterhub-odh
JH_ODH_REF ?= master

IMAGE=$(IMAGE_NAME):$(IMAGE_TAG)
TARGET=quay.io/$(QUAY_REPO)/$(IMAGE_NAME):$(IMAGE_TAG)
GIT_REPO_URL=https://github.com/$(GIT_USER)/${REPO}
JH_ODH_REPO_URL=https://github.com/$(GIT_USER)/${JH_ODH_REPO}




all: namespace prep-dc local
legacy: namespace prep-is local-legacy
remote: namespace apply build rollout
remote-odh: namespace apply apply-odh build-odh build rollout

local: build-local tag push rollout
local-legacy: build-local tag push import rollout

build-local:
	podman build . --build-arg user=$(GIT_USER) --build-arg branch=$(GIT_REF) --build-arg repo=${GIT_REPO} --no-cache -t $(IMAGE) -f ${DOCKERFILE}

tag:
	podman tag $(IMAGE) $(TARGET)

push:
	podman push $(TARGET)

import:
	oc import-image -n $(NAMESPACE) jupyterhub-img

rollout:
	oc rollout -n $(NAMESPACE) latest jupyterhub

prep-is:
	oc patch imagestream/jupyterhub-img -n $(NAMESPACE) -p '{"spec":{"tags":[{"name":"latest","from":{"name":"'$(TARGET)'"}}]}}'

prep-dc:
	oc patch deploymentconfig/jupyterhub -n $(NAMESPACE) -p '{"spec":{"template":{"spec":{"initContainers":[{"name":"wait-for-database", "image":"'${TARGET}'"}],"containers":[{"name":"jupyterhub","image":"'${TARGET}'"}]}}}}'

apply:
	cat openshift/imagestream.yaml |\
		sed 's/namespace: .*/namespace: $(NAMESPACE)/' |\
	oc apply -f - &&\
	cat openshift/build.yaml |\
		 sed 's@{"name": "branch".*}@{"name": "branch", "value": \"'$(GIT_REF)'\"}@' |\
		 sed 's@{"name": "user".*}@{"name": "user", "value": \"'$(GIT_USER)'\"}@' |\
		 sed 's/namespace: .*/namespace: $(NAMESPACE)/' |\
	oc apply -f - &&\
	oc patch deploymentconfig/jupyterhub -n $(NAMESPACE) -p '{"spec":{"template":{"spec":{"initContainers":[{"name":"wait-for-database", "image":"jupyterhub-img:latest"}],"containers":[{"name":"jupyterhub","image":"jupyterhub-img:latest"}]}}}}'

apply-odh:
	cat openshift/build-odh.yaml |\
		sed 's/namespace: .*/namespace: $(NAMESPACE)/' |\
	oc apply -f - &&\
	cat openshift/build-jh-odh.yaml |\
		sed 's/namespace: .*/namespace: $(NAMESPACE)/' |\
		sed 's@uri: .*@uri: $(JH_ODH_REPO_URL)@' |\
		sed 's@ref: .*@ref: $(JH_ODH_REF)@' |\
	oc apply -f -
	

build-odh:
	oc start-build -n $(NAMESPACE) build-jh-odh -F

build:
	oc start-build -n $(NAMESPACE) jupyterhub-img-wrapper -F

odh-deploy: namespace
	oc apply -f odh/output/manifests.yaml

odh-prep:
	pushd odh &&\
	rm -rf kustomize .cache &&\
	mkdir -p output &&\
	sed -i 's/namespace: .*/namespace: $(NAMESPACE)/' kfdef.yaml &&\
	$(KFCTL) build -V --dump -f kfdef.yaml > output/manifests.yaml &&\
	popd

namespace:
	oc new-project $(NAMESPACE) || true

route:
	oc get route -n $(NAMESPACE) jupyterhub -o jsonpath="https://{.spec.host}" && echo

clean:
	oc delete project ${NAMESPACE}
