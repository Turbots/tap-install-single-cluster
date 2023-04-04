#!/bin/zsh

source 00-functions.sh

loadSetting '.tap.registry.hostname' 'INSTALL_REGISTRY_HOSTNAME'
loadSetting '.tap.registry.username' 'INSTALL_REGISTRY_USERNAME'
loadSetting '.tap.registry.password' 'INSTALL_REGISTRY_PASSWORD' '-p'

loadSetting '.essentials.registry.hostname' 'ESSENTIALS_REGISTRY_HOSTNAME'

loadSetting '.tap.developer.namespace' 'DEVELOPER_NAMESPACE'

loadSetting '.tap.developer.registry.hostname' 'DEVELOPER_REGISTRY_HOSTNAME'
loadSetting '.tap.developer.registry.username' 'DEVELOPER_REGISTRY_USERNAME'
loadSetting '.tap.developer.registry.password' 'DEVELOPER_REGISTRY_PASSWORD' '-p'

loadSetting '.gitops_repository.server_address' 'GITOPS_SERVER'
loadSetting '.gitops_repository.owner' 'GITOPS_OWNER'
loadSetting '.gitops_repository.access_token' 'GITOPS_TOKEN' '-p'

loadSetting '.harbor.version' 'HARBOR_VERSION'

export PROFILE_FILE='full-profile.yaml'

function install_tap_view_profile() {
    mkdir -p $GENERATED_DIR

    info "Creating developer namespace ${DEVELOPER_NAMESPACE}"

    kapp deploy --app "tap-dev-ns-${DEVELOPER_NAMESPACE}" -n tap-install \
        --file <(\
            kubectl create namespace "${DEVELOPER_NAMESPACE}" \
            --dry-run=client \
            --output=yaml \
            --save-config \
        ) --yes

    info "Adding $INSTALL_REGISTRY_HOSTNAME as the main registry secret"
    
    tanzu secret registry -n tap-install add tap-registry \
        --server "${INSTALL_REGISTRY_HOSTNAME}" \
        --username "${INSTALL_REGISTRY_USERNAME}" \
        --password "${INSTALL_REGISTRY_PASSWORD}" \
        --export-to-all-namespaces \
        --yes

    info "Configuring TAP $TAP_VERSION repository"

    tanzu package repository -n tap-install add tanzu-tap-repository \
        --url $INSTALL_REGISTRY_HOSTNAME/tanzu-application-platform/tap-packages:$TAP_VERSION

    ytt -f "$VALUES_DIR/$PROFILE_FILE" -f "$VALUES_DIR/default.yaml" --ignore-unknown-comments > "$GENERATED_DIR/$PROFILE_FILE"

    info "Installing Cert Manager"

    kapp deploy --app "cert-manager-rbac" -n tap-install \
        --file <(\
            kubectl apply -f $VALUES_DIR/cert-manager-rbac.yaml \
            --dry-run=client \
            --output=yaml
        ) --yes
    
    kapp deploy --app "cert-manager-install" -n tap-install \
        --file <(\
            kubectl apply -f $VALUES_DIR/cert-manager-install.yaml \
            --dry-run=client \
            --output=yaml
        ) --yes

    info "Installing Contour"

    kapp deploy --app "contour-rbac" -n tap-install \
        --file <(\
            kubectl apply -f $VALUES_DIR/contour-rbac.yaml \
            --dry-run=client \
            --output=yaml
        ) --yes
    
    kapp deploy --app "contour-install" -n tap-install \
        --file <(\
            kubectl apply -f $VALUES_DIR/contour-install.yaml \
            --dry-run=client \
            --output=yaml
        ) --yes

    info "Configuring automated DNS certificates"

    kapp deploy -n tap-install -a lets-encrypt-issuer \
        --file <(\
            ytt -f $VALUES_DIR/default.yaml -f $VALUES_DIR/letsencrypt.yaml --ignore-unknown-comments \
        ) --yes

    kapp deploy -n tap-install -a certificates \
        --file <(\
            ytt -f $VALUES_DIR/default.yaml -f $VALUES_DIR/certificates.yaml --ignore-unknown-comments \
        ) --yes

    info "Installing Harbor $HARBOR_VERSION"
    
    tanzu package repository add tanzu-standard --url projects.registry.vmware.com/tkg/packages/standard/repo:v1.6.0 -n tap-install

    ytt -f "$VALUES_DIR/harbor.yaml" -f "$VALUES_DIR/default.yaml" --ignore-unknown-comments > "$GENERATED_DIR/harbor.yaml"

    tanzu package install harbor -n tap-install \
        --package-name harbor.tanzu.vmware.com \
        --version $HARBOR_VERSION \
        --values-file $GENERATED_DIR/harbor.yaml

    kapp deploy -n tap-install -a harbor-overlay --file \
    <(\
        kubectl -n tap-install create secret generic harbor-overlay \
          -o yaml \
          --dry-run=client \
          --from-file=$VALUES_DIR/harbor-overlay.yaml
    ) --yes

    kubectl -n tap-install annotate packageinstalls harbor ext.packaging.carvel.dev/ytt-paths-from-secret-name.1=harbor-overlay --overwrite
 
    info "Harbor installed successfully on $1"
    
    info "Installing TAP $TAP_VERSION"

    tanzu package install tap -n tap-install \
        --package-name tap.tanzu.vmware.com \
        --version $TAP_VERSION \
        --values-file "$GENERATED_DIR/$PROFILE_FILE"
}

function relocate_images_for_tds() {
    info "Relocating Tanzu Data Services container images from $ESSENTIALS_REGISTRY_HOSTNAME to $DEV_REGISTRY_HOSTNAME."
    kapp deploy -n tap-install -a relocate-job \
        --file <(\
            ytt -f $VALUES_DIR/default.yaml -f $VALUES_DIR/harbor-job.yaml --ignore-unknown-comments \
        ) --yes
}

loginToGuestCluster $KUBECTX_SV_CLUSTER $KUBECTL_SV_NAMESPACE $KUBECTX_TAP_CLUSTER_NAME

info "Installing TAP Full Profile on $KUBECTX_TAP_CLUSTER_NAME"
install_tap_view_profile
relocate_images_for_tds

success "TAP installation on $KUBECTX_TAP_CLUSTER_NAME has completed."