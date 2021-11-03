#!/usr/bin/env bash

while [[ $# -gt 0 ]]; do
  key="$1"

  case $key in
  -an | --admin-name)
    ADMIN_NAME="$2"
    shift # past argument
    shift # past value
    ;;
  -ap | --admin-password)
    ADMIN_PASS="$2"
    shift # past argument
    shift # past value
    ;;
  -ag | --admin-group)
    ADMIN_GROUP="$2"
    shift # past argument
    shift # past value
    ;;
  -un | --user-name)
    USER_NAME="$2"
    shift # past argument
    shift # past value
    ;;
  -up | --user-password)
    USER_PASS="$2"
    shift # past argument
    shift # past value
    ;;
  -ug | --user-group)
    USER_GROUP="$2"
    shift # past argument
    shift # past value
    ;;
  -n | --namespace)
    NAMESPACE="$2"
    shift # past argument
    shift # past value
    ;;
  *) # unknown option
    shift # past argument
    ;;
  esac
done

if [ -z "$ADMIN_NAME" ]; then
  echo -an or -admin-name must be supplied
  exit
fi
if [ -z "$ADMIN_PASS" ]; then
  echo -ap or -admin-password must be supplied
  exit
fi
if [ -z "$ADMIN_GROUP" ]; then
  echo -ag or -admin-group must be supplied
  exit
fi
if [ -z "$USER_NAME" ]; then
  echo -un or -user-name must be supplied
  exit
fi
if [ -z "$USER_PASS" ]; then
  echo -up or -user-password must be supplied
  exit
fi
if [ -z "USER_GROUP" ]; then
  echo -ug or -user-group must be supplied
  exit
fi
if [ -z "$NAMESPACE" ]; then
  echo -n or -namespace must be supplied
  exit
fi

TEMP_DIR="openshift/temp"
mkdir -p ${TEMP_DIR}

OC_USERS_LIST="$(oc get users)"

ADMIN_HTPASSWD_FILE="${TEMP_DIR}/${ADMIN_NAME}.htpasswd"
ADMIN_HTPASSWD_SECRET="htpasswd-${ADMIN_NAME}-secret"

if echo "${OC_USERS_LIST}" | grep -q -w "${ADMIN_NAME}"; then
  echo -e "\033[0;32m \xE2\x9C\x94 User ${ADMIN_NAME} already exists \033[0m"
else
  SECRET="$(oc get secret ${ADMIN_HTPASSWD_SECRET} -n openshift-config --ignore-not-found=true --no-headers | grep -w ${ADMIN_HTPASSWD_SECRET})"
  if [ -z "${SECRET}" ]; then
    echo Creating ${ADMIN_NAME} credentials
    htpasswd -cb ${ADMIN_HTPASSWD_FILE} ${ADMIN_NAME} ${ADMIN_PASS}
    oc create secret generic ${ADMIN_HTPASSWD_SECRET} --from-file=htpasswd=${ADMIN_HTPASSWD_FILE} -n openshift-config
    rm ${ADMIN_HTPASSWD_FILE}
  else
    echo -e "\033[0;32m \xE2\x9C\x94 Credentials for ${ADMIN_NAME} already exists (not necessarily this password!) \033[0m"
  fi
fi

USER_HTPASSWD_FILE="${TEMP_DIR}/${USER_NAME}.htpasswd"
USER_HTPASSWD_SECRET="htpasswd-${USER_NAME}-secret"

if echo "${OC_USERS_LIST}" | grep -q -w "${USER_NAME}"; then
  echo -e "\033[0;32m \xE2\x9C\x94 User ${USER_NAME} already exists \033[0m"
else
  SECRET="$(oc get secret ${USER_HTPASSWD_SECRET} -n openshift-config --ignore-not-found=true --no-headers | grep -w ${USER_HTPASSWD_SECRET})"
  if [ -z "${SECRET}" ]; then
    echo Creating ${USER_NAME} credentials
    htpasswd -cb ${USER_HTPASSWD_FILE} ${USER_NAME} ${USER_PASS}
    oc create secret generic ${USER_HTPASSWD_SECRET} --from-file=htpasswd=${USER_HTPASSWD_FILE} -n openshift-config
    rm ${USER_HTPASSWD_FILE}
  else
    echo -e "\033[0;32m \xE2\x9C\x94 Credentials for ${USER_NAME} already exists (not necessarily this password!) \033[0m"
  fi
fi

OAUTHS="$(oc get oauth/cluster -o custom-columns=CONTAINER:.spec.identityProviders --no-headers)"
OAUTH_FOUND=$(echo "${OAUTHS}" | grep -v "<none>")

# Create the cluster OAUTH if necessary
if [ -z "${OAUTH_FOUND}" ]; then
  echo Creating OAuth...
  oc apply -f - <<EOF
apiVersion: config.openshift.io/v1
kind: OAuth
metadata:
  name: cluster
spec:
  identityProviders:
    - name: ${ADMIN_NAME}
      mappingMethod: claim
      challenge: true
      login: true
      type: HTPasswd
      htpasswd:
        fileData:
          name: ${ADMIN_HTPASSWD_SECRET}
    - name: ${USER_NAME}
      mappingMethod: claim
      challenge: true
      login: true
      type: HTPasswd
      htpasswd:
        fileData:
          name: ${USER_HTPASSWD_SECRET}
EOF
else
  OAUTH_NAMES="$(oc get oauth -o custom-columns=CONTAINER:.spec.identityProviders[\*].name --no-headers)"

  ADMIN_FOUND=$(echo "${OAUTH_NAMES}" | grep -w ${ADMIN_NAME})
  if [ -z "${ADMIN_FOUND}" ]; then
    echo "adding ${ADMIN_NAME} to OAuth"
    oc patch oauth cluster --type='json' --patch "
    [
      {
        \"op\": \"add\",
        \"path\": \"/spec/identityProviders/-\",
        \"value\": {
          \"name\": \"${ADMIN_NAME}\",
          \"mappingMethod\": \"claim\",
          \"challenge\": \"true\",
          \"login\": \"true\",
          \"type\": \"HTPasswd\",
          \"htpasswd\":
            {
              \"fileData\": {
                \"name\": \"${ADMIN_HTPASSWD_SECRET}\"
              }
            }
        }
      }
    ]"
  else
    echo -e "\033[0;32m \xE2\x9C\x94 ${ADMIN_NAME} already in OAuth \033[0m"
  fi

  USER_FOUND=$(echo "${OAUTH_NAMES}" | grep -w ${USER_NAME})
  if [ -z "${USER_FOUND}" ]; then
  echo "adding ${USER_NAME} to OAuth"
    oc patch oauth cluster --type='json' --patch "
    [
      {
        \"op\": \"add\",
        \"path\": \"/spec/identityProviders/-\",
        \"value\": {
          \"name\": \"${USER_NAME}\",
          \"mappingMethod\": \"claim\",
          \"challenge\": \"true\",
          \"login\": \"true\",
          \"type\": \"HTPasswd\",
          \"htpasswd\":
            {
              \"fileData\": {
                \"name\": \"${USER_HTPASSWD_SECRET}\"
              }
            }
        }
      }
    ]"
  else
      echo -e "\033[0;32m \xE2\x9C\x94 ${USER_NAME} already in OAuth \033[0m"
  fi
fi

ROLE_BINDINGS="$(oc get rolebindings -n ${NAMESPACE} -o custom-columns=CONTAINER:.metadata.name --no-headers)"

ADMIN_RB_FOUND=$(echo "${ROLE_BINDINGS}" | grep -w "ods-admin")
if [ -z "${ADMIN_RB_FOUND}" ]; then
  echo Creating Admin Role binding...
oc apply -f - <<EOF
kind: RoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: ods-admin
  namespace: ${NAMESPACE}
subjects:
  - kind: User
    apiGroup: rbac.authorization.k8s.io
    name: ${ADMIN_NAME}
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: admin
EOF
else
  RB_SUBJECTS="$(oc get rolebindings/ods-admin -n ${NAMESPACE}  -o custom-columns=CONTAINER:.subjects[\*].name --no-headers | sed -e "s/,/ /g")"
  SUBJECT_FOUND=$(echo ${RB_SUBJECTS} | grep -w ${ADMIN_NAME})
  if [ -z "${SUBJECT_FOUND}" ]; then
    echo Patching RoleBinding with ${ADMIN_NAME}
    oc patch rolebinding/ods-admin -n ${NAMESPACE} --type='json' --patch "
    [
      {
        \"op\": \"add\",
        \"path\": \"/subjects/-\",
        \"value\": {
          \"name\": \"${ADMIN_NAME}\",
          \"kind\": \"User\",
          \"apiGroup\": \"rbac.authorization.k8s.io\",
        }
      }
    ]"
  fi
fi

USER_RB_FOUND=$(echo "${ROLE_BINDINGS}" | grep -w "ods-user")
if [ -z "${USER_RB_FOUND}" ]; then
  echo Creating RoleBinding for ${USER_NAME}
  oc apply -f - <<EOF
kind: RoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: ods-user
  namespace: ${NAMESPACE}
subjects:
  - kind: User
    apiGroup: rbac.authorization.k8s.io
    name: ${USER_NAME}
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: basic-user
EOF
else
  RB_SUBJECTS="$(oc get rolebindings/ods-user -n ${NAMESPACE}  -o custom-columns=CONTAINER:.subjects[\*].name --no-headers | sed -e "s/,/ /g")"
  SUBJECT_FOUND=$(echo ${RB_SUBJECTS} | grep -w ${USER_NAME})
  if [ -z "${SUBJECT_FOUND}" ]; then

    echo Patching RoleBinding with ${USER_NAME}
    oc patch rolebinding/ods-user -n ${NAMESPACE} --type='json' --patch "
    [
      {
        \"op\": \"add\",
        \"path\": \"/subjects/-\",
        \"value\": {
          \"name\": \"${USER_NAME}\",
          \"kind\": \"User\",
          \"apiGroup\": \"rbac.authorization.k8s.io\",
        }
      }
    ]"
  fi
fi

echo Adding users to groups
oc patch group/${ADMIN_GROUP} --type='json' -p "[{\"op\": \"add\", \"path\":\"/users/-\", \"value\":\"${ADMIN_NAME}\"}]"
oc patch group/${USER_GROUP} --type='json' -p "[{\"op\": \"add\", \"path\":\"/users/-\", \"value\":\"${USER_NAME}\"}]"

oc adm policy add-role-to-user view ${USER_NAME} -n ${NAMESPACE}

echo -e "\033[0;32m User ${ADMIN_NAME} created, login with: \033[0m oc login -u ${ADMIN_NAME} -p ${ADMIN_PASS}"
echo -e "\033[0;32m User ${USER_NAME} created, login with: \033[0m oc login -u ${USER_NAME} -p ${USER_PASS}"
