#!/bin/zsh

source 00-functions.sh

loginToSupervisorCluster $KUBECTX_SV_CLUSTER
loginToGuestCluster $KUBECTX_SV_CLUSTER $KUBECTL_SV_NAMESPACE $KUBECTX_TAP_CLUSTER_NAME

success "Logged in to all clusters!"