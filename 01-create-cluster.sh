#!/bin/zsh

source 00-functions.sh

function deploy_cluster() {
    info "Provisioning workload clusters in Supervisor Cluster $1"

    kubectx $1
    
    kubectl apply -f values/cluster-definition.yaml -n $SV_NAMESPACE`
}

install_vsphere_plugin $KUBECTX_SV_CLUSTER

loginToSupervisorCluster $KUBECTX_SV_CLUSTER

deploy_cluster $KUBECTX_SV_CLUSTER

success "Cluster provisioning initialized!"