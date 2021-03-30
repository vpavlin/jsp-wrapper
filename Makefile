REPO=$(USER)
IMAGE_NAME=jupyterhub-img
IMAGE_TAG=test-jsp
NAMESPACE=opendatahub

IMAGE=$(IMAGE_NAME):$(IMAGE_TAG)
TARGET=quay.io/$(REPO)/$(IMAGE_NAME):$(IMAGE_TAG)


all: prep-is local
remote: apply build rollout

local: build-local tag push import 

build-local:
	podman build . -t $(IMAGE)

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
	oc apply -f openshift/

build:
	oc start-build -n $(NAMESPACE) jupyterhub-img-wrapper -F
