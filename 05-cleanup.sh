#!/bin/zsh

source 00-functions.sh

function delete_cluster() {
    info "Delete TAP Cluster in Supervisor Cluster $1"

    kubectx $1
    
    kubectl delete -f cluster-definition.yaml -n $KUBECTL_SV_NAMESPACE --wait=false
}

install_vsphere_plugin $KUBECTX_SV_CLUSTER

loginToSupervisor $KUBECTX_SV_CLUSTER

delete_cluster $KUBECTX_SV_CLUSTER

success "Clusters Deleted!"