#!/bin/bash
PULSAR_HOME=$(dirname $(realpath $0))
MULTI_STANDALONE_CONFIG=$PULSAR_HOME/multi-standalone-config.yaml

if [[ "$OSTYPE" == "darwin"* ]]; then
    mac_os_deps=("gnu-sed")
    if ! type -P brew &>/dev/null; then
        echo "On MacOSX, you must install gnu binaries with the following command:"
        echo "brew install" "${mac_os_deps[@]}"
        exit 1
    fi
    for dep in "${mac_os_deps[@]}"; do
        path_element="$(brew --prefix)/opt/${dep}/libexec/gnubin"
        if [ ! -d "${path_element}" ]; then
            echo "'${path_element}' is missing. Quick fix: 'brew install ${dep}'."
            echo "On MacOSX, you must install gnu binaries with the following command:"
            echo "brew install" "${mac_os_deps[@]}"
            exit 1
        fi
        PATH="${path_element}:$PATH"
    done
    export PATH
fi

function check_app() {
    app="$1"
    linuxbrew="${2:-0}"
    package="${3:-${app}}"
    if ! type -P $app &>/dev/null; then
        echo "$app is required, but it wasn't found. Install it with the following command:"
        if [[ "$OSTYPE" == "darwin"* || "${linuxbrew}" == "1" ]]; then
            echo "brew install $package"
        else
            echo "sudo apt-get install $package"
        fi
        exit 1
    fi
}

check_app yq 1

function exit_if_config_not_found(){
    [[ ! -f $MULTI_STANDALONE_CONFIG ]] && \
        echo "multi-standalone-config.yaml not found in $PULSAR_HOME, please provide configuration file." && \
        exit 1
}

function startup_multi_standalone(){
    exit_if_config_not_found
    
    mode="${1:-noclean}"
    local cur_sa_data_dir=""
    local cur_sa_config=""
    local cur_sa_bk_port=""
    local cur_sa_broker_port=""
    local cur_sa_log_file=""

    if [[ ! -h ${PULSAR_HOME}/conf/standalone.conf ]]; then
        mv "${PULSAR_HOME}/conf/standalone.conf" "${PULSAR_HOME}/conf/standalone-default.conf"
    fi  
    
    for cluster_name in $(yq e '.clusters[].name' ${MULTI_STANDALONE_CONFIG}); do
        cur_sa_data_dir="${PULSAR_HOME}/data-${cluster_name}"
        cur_sa_config="${PULSAR_HOME}/conf/standalone-${cluster_name}.conf"
        
        cp "${PULSAR_HOME}/conf/standalone-default.conf" "${cur_sa_config}"
        
        cur_sa_broker_port=$(clusterName=${cluster_name} \
                         yq e '.clusters[] | select(.name == env(clusterName)) | .broker.servicePort' ${MULTI_STANDALONE_CONFIG})
        cur_sa_web_port=$(clusterName=${cluster_name} \
                         yq e '.clusters[] | select(.name == env(clusterName)) | .broker.webPort' ${MULTI_STANDALONE_CONFIG})
        
        sed -i "s/brokerServicePort=6650/brokerServicePort=${cur_sa_broker_port}/g" "${cur_sa_config}"
        sed -i "s/webServicePort=8080/webServicePort=${cur_sa_web_port}/g" "${cur_sa_config}"
        rm "${PULSAR_HOME}/conf/standalone.conf"
        ln -s "${cur_sa_config}" "${PULSAR_HOME}/conf/standalone.conf"
        
        if [[ "$mode" == "clean" ]]; then
            rm -rf "$cur_sa_data_dir"
        fi
        mkdir -p "${cur_sa_data_dir}"
        
        cur_sa_bk_port=$(clusterName=${cluster_name} \
                                    yq e '.clusters[] | select(.name == env(clusterName)) | .bookkeeper.port' ${MULTI_STANDALONE_CONFIG})
        
        cur_sa_log_file="/tmp/${cluster_name}-standalone-$(date +%s).log"
        echo "Starting \"$cluster_name\" standalone cluster with the following settings: "
        clusterName=${cluster_name} yq e '.clusters[] | select(.name == env(clusterName))' ${MULTI_STANDALONE_CONFIG}
        echo "Storing cluster logs in ${cur_sa_log_file}"

        local standalone_version_flags=""
        cur_sa_zk_port=$(clusterName=${cluster_name} yq e '.clusters[] | select(.name == env(clusterName)) | .zookeeper.port' ${MULTI_STANDALONE_CONFIG})
        if [[ $(${PULSAR_HOME}/bin/pulsar version | grep -c '2.10') -eq 1  ]]; then
            standalone_version_flags="--zookeeper-port ${cur_sa_zk_port} --zookeeper-dir ${cur_sa_data_dir}/standalone/zookeeper"
        elif [[ $(${PULSAR_HOME}/bin/pulsar version | grep -c '2.11') -eq 1  ]]; then
            standalone_version_flags="--metadata-dir ${cur_sa_data_dir}"
        else
            echo "Pulsar version not supported (only 2.10 and 2.11 are supported)"
            exit 1
        fi
        
        set -x
        ${PULSAR_HOME}/bin/pulsar standalone -nss -nfw --wipe-data \
                      --bookkeeper-dir "${cur_sa_data_dir}/standalone/bookkeeper" \
                      --bookkeeper-port "${cur_sa_bk_port}" \
                      "${standalone_version_flags}" \
                      "$@" > "${cur_sa_log_file}" 2>&1 &
        set +x
        sleep 10
    done
}
