FROM quay.io/odh-jupyterhub/jupyterhub-img:v0.2.5

ADD run.sh /tmp/run.sh

RUN pip install git+https://github.com/vpavlin/jupyterhub-singleuser-profiles.git@master#egg=jupyterhub-singleuser-profiles

RUN bash /tmp/run.sh