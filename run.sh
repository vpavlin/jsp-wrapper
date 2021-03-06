#!/bin/bash

set -x

JSP_UI_SRC_PATH=/opt/app-root/src/jupyterhub-singleuser-profiles/jupyterhub_singleuser_profiles/ui/

cd ${JSP_UI_SRC_PATH}

npm install
npm run build

cd /opt/app-root/share/jupyterhub/static/
mkdir jsp-ui
cp -a ${JSP_UI_SRC_PATH}/build/. /opt/app-root/share/jupyterhub/static/jsp-ui

cd ${JSP_UI_SRC_PATH}/templates/
yes | cp -rf spawn.html /opt/app-root/share/jupyterhub/templates/
cd ${JSP_UI_SRC_PATH}/styles/
yes | cp -rf style.less /opt/app-root/share/jupyterhub/static/less

fix-permissions /opt/app-root