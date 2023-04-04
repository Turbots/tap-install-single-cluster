#!/bin/zsh

source 00-functions.sh

loadSetting '.essentials.tanzu_network_token' 'TANZU_NETWORK_TOKEN' '-p'
loadSetting '.supervisor.hostname' 'KUBECTX_SV_CLUSTER'
loadSetting '.essentials.version' 'CLUSTER_ESSENTIALS_VERSION'
loadSetting '.essentials.bundle' 'INSTALL_BUNDLE'
loadSetting '.essentials.registry.hostname' 'INSTALL_REGISTRY_HOSTNAME'
loadSetting '.essentials.registry.username' 'INSTALL_REGISTRY_USERNAME'
loadSetting '.essentials.registry.password' 'INSTALL_REGISTRY_PASSWORD' '-p'

function download_cluster_essentials() {
    mkdir -p downloads
    if [[ ! -f "downloads/tanzu-cluster-essentials-$PLATFORM-amd64-$1.tgz" ]]; then
        curl -L -H "Authorization: Token $TANZU_NETWORK_TOKEN" -o "downloads/tanzu-cluster-essentials-$PLATFORM-amd64-$1.tgz" "https://network.tanzu.vmware.com/api/v2/products/tanzu-cluster-essentials/releases/1180593/product_files/1330472/download"
    else
        info "Cluster essentials already downloaded - Skipping!"
    fi
}

function unpack_cluster_essentials() {
    info "Unpacking cluster essentials"

    mkdir -p downloads/tanzu-cluster-essentials
    tar -xvf downloads/tanzu-cluster-essentials-$PLATFORM-amd64-$1.tgz -C downloads/tanzu-cluster-essentials
}

function install_cluster_essentials() {
    info "Installing cluster essentials on $1"

    kubectx $1

    kubectl create clusterrolebinding default-tkg-admin-privileged-binding \
        --clusterrole=psp:vmware-system-privileged \
        --group=system:authenticated \
        --dry-run=client -o yaml | kubectl apply -f -

    cd downloads/tanzu-cluster-essentials
    ./install.sh --yes
    cd ../../

    downloads/tanzu-cluster-essentials/kapp deploy --app tap-install-ns -n tanzu-cluster-essentials --file \
    <(\
        kubectl create namespace tap-install \
        --dry-run=client \
        --output=yaml \
        --save-config \
    ) --yes

    success "Cluster essentials successfully installed on $1."
}

download_cluster_essentials $CLUSTER_ESSENTIALS_VERSION
unpack_cluster_essentials $CLUSTER_ESSENTIALS_VERSION

loginToGuestCluster $KUBECTX_SV_CLUSTER $KUBECTL_SV_NAMESPACE $KUBECTX_TAP_CLUSTER_NAME

install_cluster_essentials $KUBECTX_TAP_CLUSTER_NAME