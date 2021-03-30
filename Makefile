REPO=$(USER)
IMAGE_NAME=jupyterhub-img
IMAGE_TAG=test-jsp
NAMESPACE ?= opendatahub
GIT_REF ?= master

IMAGE=$(IMAGE_NAME):$(IMAGE_TAG)
TARGET=quay.io/$(REPO)/$(IMAGE_NAME):$(IMAGE_TAG)
GIT_REPO=https://github.com/$(USER)/jupyterhub-singleuser-profiles



all: prep-is local
remote: apply build rollout

local: build-local tag push import rollout

build-local:
	podman build . --build-arg user=$(USER) --build-arg branch=$(GIT_REF) -t $(IMAGE)

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

apply:
	cat openshift/build.yaml | sed 's@uri: .*@uri: $(GIT_REPO)@' | sed 's@ref: .*@ref: $(GIT_REF)@' | sed 's/namespace: .*/namespace: $(NAMESPACE)/' | oc apply -f -

build:
	oc start-build -n $(NAMESPACE) jupyterhub-img-wrapper -F
