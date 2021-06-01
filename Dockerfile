FROM quay.io/vpavlin/jupyterhub-img:login-url

ARG user=vpavlin
ARG branch=master

ADD run.sh /tmp/run.sh

RUN pip install -e git+https://github.com/${user}/jupyterhub-singleuser-profiles.git@${branch}#egg=jupyterhub_singleuser_profiles

RUN bash /tmp/run.sh