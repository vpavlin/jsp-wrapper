FROM quay.io/odh-jupyterhub/jupyterhub-img:v0.2.5

ARG user=vpavlin
ARG branch=master

ADD run.sh /tmp/run.sh

RUN pip install git+https://github.com/${user}/jupyterhub-singleuser-profiles.git@${branch}#egg=jupyterhub-singleuser-profiles

RUN bash /tmp/run.sh