#!/bin/zsh

set -e
setopt aliases

autoload colors; colors

function loadSetting() {
    var=`yq $1 values/default.yaml`
    export $2=$var

    if [[ $3 == "-p" ]] ; then
        warn "Loaded env variable $2 = *****"
    else 
        warn "Loaded env variable $2 = $var"
    fi
}

function error() {
    println red "ERROR" $1
}

function warn() {
    print magenta "WARN" $1
}

function info() {
    println yellow "INFO" $1
}

function success() {
    println green "SUCCESS" $1
}

function print() {
    local paddedString=`(printf %-8s $2)`
    echo $fg[$1]"|$paddedString|"$reset_color" $3"
}

function println() {
    local paddedString=`(printf %-8s $2)`
    echo "\n"$fg[$1]"|$paddedString|"$reset_color" $3"
}

function createDirectory() {
    [ -d $1 ] || mkdir -p $1
}

function determinePlatform() {
    if [ "$(uname)" = "Darwin" ]; then
        info "Platform is Mac."
        determineIfSiliconMac
        export PLATFORM="darwin"
    elif [ "$(expr substr $(uname -s) 1 5)" = "Linux" ]; then
        info "Platform is Linux."
        export PLATFORM="linux"
    else
        warn "We don't support MINGW64_NT environments."
    fi
}

function determineIfSiliconMac() {
    if [[ $(uname -m) == 'arm64' ]]; then
        export SILICON_MAC="true"
        info "Mac has an Apple Silicon chip (ARM64 based)."
    fi
}

function install_vsphere_plugin() {
    createDirectory downloads

    if [ ! -f "downloads/vsphere-plugin-$PLATFORM.zip" ]; then
        info "Downloading Kubectl vSphere plugin for $PLATFORM"
        wget -O downloads/vsphere-plugin-$PLATFORM.zip https://$1/wcp/plugin/$PLATFORM-amd64/vsphere-plugin.zip --no-check-certificate
    fi
    info "Installing Kubectl vSphere plugin for $PLATFORM"
    unzip -o downloads/vsphere-plugin-$PLATFORM.zip -d downloads
    export PATH="$PATH:$PWD/downloads/bin"

    success "Kubectl vSphere Plugin installed"
}

function loginToSupervisorCluster() {
    info "Logging in to supervisor cluster $1"

    kubectl vsphere login -v0 --server=$1 --insecure-skip-tls-verify -u $KUBECTL_VSPHERE_USERNAME

    success "Logged in to supervisor cluster $1."
}

function loginToGuestCluster() {
    info "Logging in to $3 in vSphere namespace $2"

    kubectl vsphere login -v0 --server=$1 --insecure-skip-tls-verify -u $KUBECTL_VSPHERE_USERNAME --tanzu-kubernetes-cluster-namespace $2 --tanzu-kubernetes-cluster-name $3
    
    cp ~/.kube/config generated/kubeconfig.yaml
    ytt -f generated/kubeconfig.yaml -f values/external-ip-overlay.yaml -f values/default.yaml > ~/.kube/config

    success "Logged in to $3."
}

determinePlatform

loadSetting '.supervisor.hostname' 'KUBECTX_SV_CLUSTER'
loadSetting '.supervisor.username' 'KUBECTL_VSPHERE_USERNAME'
loadSetting '.supervisor.password' 'KUBECTL_VSPHERE_PASSWORD' '-p'
loadSetting '.supervisor.namespace' 'KUBECTL_SV_NAMESPACE'

loadSetting '.tap.cluster.name' 'KUBECTX_TAP_CLUSTER_NAME'
loadSetting '.tap.cluster.external_ip' 'KUBECTX_TAP_CLUSTER_EXTERNAL_IP'
loadSetting '.tap.version' 'TAP_VERSION'

export GENERATED_DIR="generated"
export VALUES_DIR="values"

success "Settings Initialized"