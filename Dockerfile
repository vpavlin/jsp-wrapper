FROM quay.io/odh-jupyterhub/jupyterhub-img:v0.3.4

ARG user=vpavlin
ARG branch=master

ADD run.sh /tmp/run.sh

RUN pip install -e git+https://github.com/${user}/jupyterhub-singleuser-profiles.git@${branch}#egg=jupyterhub_singleuser_profiles

RUN bash /tmp/run.sh
