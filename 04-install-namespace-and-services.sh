#!/bin/zsh

source 00-functions.sh

loadSetting '.tap.developer.namespace' 'DEVELOPER_NAMESPACE'

loadSetting '.essentials.registry.hostname' 'ESSENTIALS_REGISTRY_HOSTNAME'

loadSetting '.tap.developer.registry.hostname' 'DEVELOPER_REGISTRY_HOSTNAME'
loadSetting '.tap.developer.registry.project' 'DEVELOPER_REGISTRY_PROJECT'
loadSetting '.tap.developer.registry.username' 'DEVELOPER_REGISTRY_USERNAME'
loadSetting '.tap.developer.registry.password' 'DEVELOPER_REGISTRY_PASSWORD' '-p'

loadSetting '.tds.version' 'TDS_VERSION'
loadSetting '.tds.postgres.version' 'POSTGRES_VERSION'
loadSetting '.tds.mysql.version' 'MYSQL_VERSION'
loadSetting '.tds.rabbitmq.version' 'RABBITMQ_VERSION'

function configure_namespace() {
    info "Configuring developer namespace ${DEVELOPER_NAMESPACE} on $1"

    kubectx $1

    kapp deploy --app git-secret -n tap-install \
        --file <(\
            ytt -f $VALUES_DIR/default.yaml -f $VALUES_DIR/git-secret.yaml --ignore-unknown-comments \
        ) --yes

    tanzu secret registry -n ${DEVELOPER_NAMESPACE} add dev-registry \
        --server "${DEVELOPER_REGISTRY_HOSTNAME}" \
        --username "${DEVELOPER_REGISTRY_USERNAME}" \
        --password "${DEVELOPER_REGISTRY_PASSWORD}" \
        --yes

     kapp deploy --app developer-sa-rbac -n ${DEVELOPER_NAMESPACE} \
        --file $VALUES_DIR/permissions.yaml \
        --yes
}

function install_services() {
    info "Installing services on $1."

    kubectx $1

    info "Updating TDS repository on $1."

    tanzu package repository add tanzu-data-services-repository -n tap-install \
        --url $DEVELOPER_REGISTRY_HOSTNAME/$DEVELOPER_REGISTRY_PROJECT/tds-packages:$TDS_VERSION \
    
    info "Updating RabbitMQ repository on $1."

    tanzu package repository add tanzu-rabbitmq-repository -n tap-install \
        --url $ESSENTIALS_REGISTRY_HOSTNAME/p-rabbitmq-for-kubernetes/tanzu-rabbitmq-package-repo:$RABBITMQ_VERSION \

    info "Exporting registry secret to all namespaces."

    tanzu secret registry update registry-credentials -n $DEVELOPER_NAMESPACE --export-to-all-namespaces --yes

    info "Installing Postgres Operator $POSTGRES_VERSION."

    tanzu package install postgres-operator -n tap-install \
        --package-name postgres-operator.sql.tanzu.vmware.com \
        --version $POSTGRES_VERSION \
        -f $VALUES_DIR/postgres.yaml

    success "Postgres Operator $POSTGRES_VERSION successfully installed."

    info "Installing MySQL Operator $MYSQL_VERSION."

    tanzu package install mysql-operator -n tap-install \
        --package-name mysql-operator.with.sql.tanzu.vmware.com \
        --version $MYSQL_VERSION \
        -f $VALUES_DIR/mysql.yaml

    success "MySQL Operator $MYSQL_VERSION successfully installed."

    info "Installing RabbitMQ Operator $RABBITMQ_VERSION."

    tanzu package install rabbitmq-operator -n tap-install \
        --package-name rabbitmq.tanzu.vmware.com \
        --version $RABBITMQ_VERSION \
        --service-account-name tap-install-sa

    success "RabbitMQ Operator $MYSQL_VERSION successfully installed."

    kapp deploy --app data-services -n tap-install \
        --file $VALUES_DIR/data-services.yaml \
        --yes
    
    success "All services were installed successfully on $1."
}

loginToGuestCluster $KUBECTX_SV_CLUSTER $KUBECTL_SV_NAMESPACE $KUBECTX_TAP_CLUSTER_NAME

configure_namespace $KUBECTX_TAP_CLUSTER_NAME
install_services $KUBECTX_TAP_CLUSTER_NAME
