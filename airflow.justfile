import "juju.justfile"

# Deploy airflow using juju commands
[arg("model", long="model")]
[arg("channel", long="channel")]
[arg("airflow_rock", long="airflow-rock", value="true")]
[arg("coordinator_charm", long="coordinator-charm", value="true")]
[arg("api_server_charm", long="api-server-charm", value="true")]
[arg("scheduler_charm", long="scheduler-charm", value="true")]
[arg("dag_processor_charm", long="dag-processor-charm", value="true")]
[arg("triggerer_charm", long="triggerer-charm", value="true")]
airflow-deploy model="airflow" channel="3.1/edge" airflow_rock="" coordinator_charm="" api_server_charm="" scheduler_charm="" dag_processor_charm="" triggerer_charm="":
    #!/usr/bin/bash
    set -eux

    if [ -n "$airflow_rock" ]; then
        just airflow-pack-rock

        just docker-start-local-registry
        just docker-push-rock-to-local-registry $(ls $JUST_TEMP_DIR_LOCATION/rocks/airflow*.rock) airflow dev2
    fi

    if [ -n "$coordinator_charm" ]; then
        just airflow-pack-coordinator
        coordinator_charm=$(ls $JUST_TEMP_DIR_LOCATION/charms/airflow-coordinator*.charm)
    fi

    if [ -n "$api_server_charm" ]; then
        just airflow-pack-api-server
        api_server_charm=$(ls $JUST_TEMP_DIR_LOCATION/charms/airflow-api-server*.charm)
    fi

    if [ -n "$scheduler_charm" ]; then
        just airflow-pack-scheduler
        scheduler_charm=$(ls $JUST_TEMP_DIR_LOCATION/charms/airflow-scheduler*.charm)
    fi

    if [ -n "$dag_processor_charm" ]; then
        just airflow-pack-dag-processor
        dag_processor_charm=$(ls $JUST_TEMP_DIR_LOCATION/charms/airflow-dag-processor*.charm)
    fi

    if [ -n "$triggerer_charm" ]; then
        just airflow-pack-triggerer
        triggerer_charm=$(ls $JUST_TEMP_DIR_LOCATION/charms/airflow-triggerer*.charm)
    fi

    just juju-add-model $model

    just juju-update-status-interval 5s

    juju deploy postgresql-k8s --channel 14/stable --trust
    juju deploy pgbouncer-k8s --channel 1/stable --trust

    juju deploy \
        ${coordinator_charm:+${coordinator_charm}} \
        airflow-coordinator-k8s \
        --channel $channel \
        ${airflow_rock:+--resource airflow-coordinator-image=localhost:5000/airflow:dev2}

    juju deploy \
        ${api_server_charm:+$api_server_charm} \
        airflow-api-server-k8s \
        --channel $channel \
        ${airflow_rock:+--resource airflow-api-server-image=localhost:5000/airflow:dev2}

    juju deploy \
        ${scheduler_charm:+$scheduler_charm} \
        airflow-scheduler-k8s \
        --channel $channel \
        ${airflow_rock:+--resource airflow-scheduler-image=localhost:5000/airflow:dev2}

    juju deploy \
        ${dag_processor_charm:+$dag_processor_charm} \
        airflow-dag-processor-k8s \
        --channel $channel \
        ${airflow_rock:+--resource airflow-dag-processor-image=localhost:5000/airflow:dev2}

    juju deploy \
        ${triggerer_charm:+$triggerer_charm} \
        airflow-triggerer-k8s \
        --channel $channel \
        ${airflow_rock:+--resource airflow-triggerer-image=localhost:5000/airflow:dev2}

    juju integrate postgresql-k8s pgbouncer-k8s

    juju integrate pgbouncer-k8s airflow-coordinator-k8s

    juju integrate airflow-api-server-k8s:airflow-api-server airflow-coordinator-k8s

    juju integrate airflow-coordinator-k8s:airflow-coordinator airflow-api-server-k8s
    juju integrate airflow-coordinator-k8s:airflow-coordinator airflow-scheduler-k8s
    juju integrate airflow-coordinator-k8s:airflow-coordinator airflow-dag-processor-k8s
    juju integrate airflow-coordinator-k8s:airflow-coordinator airflow-triggerer-k8s

    juju status --relations --storage

# Pack airflow-coordinator charm
airflow-pack-coordinator:
    mkdir -p $JUST_TEMP_DIR_LOCATION/charms

    charmcraft pack --project-dir $AIRFLOW_COORDINATOR_REPO_LOCATION

    mv airflow-coordinator*.charm $JUST_TEMP_DIR_LOCATION/charms

# Pack airflow-api-server charm
airflow-pack-api-server:
    mkdir -p $JUST_TEMP_DIR_LOCATION/charms

    charmcraft pack --project-dir $AIRFLOW_CORE_REPO_LOCATION/charms/api-server

    mv airflow-api-server*.charm $JUST_TEMP_DIR_LOCATION/charms


# Pack airflow-scheduler charm
airflow-pack-scheduler:
    mkdir -p $JUST_TEMP_DIR_LOCATION/charms

    charmcraft pack --project-dir $AIRFLOW_CORE_REPO_LOCATION/charms/scheduler

    mv airflow-scheduler*.charm $JUST_TEMP_DIR_LOCATION/charms

# Pack airflow-dag-processor charm
airflow-pack-dag-processor:
    mkdir -p $JUST_TEMP_DIR_LOCATION/charms

    charmcraft pack --project-dir $AIRFLOW_CORE_REPO_LOCATION/charms/dag-processor

    mv airflow-dag-processor*.charm $JUST_TEMP_DIR_LOCATION/charms

# Pack airflow-triggerer charm
airflow-pack-triggerer:
    mkdir -p $JUST_TEMP_DIR_LOCATION/charms

    charmcraft pack --project-dir $AIRFLOW_CORE_REPO_LOCATION/charms/triggerer

    mv airflow-triggerer*.charm $JUST_TEMP_DIR_LOCATION/charms

# Pack airflow-rock
airflow-pack-rock version="3.1":
    #!/usr/bin/bash
    cd $AIRFLOW_ROCK_REPO_LOCATION/${version}

    rockcraft pack

    mkdir -p $JUST_TEMP_DIR_LOCATION/rocks
    mv airflow*.rock $JUST_TEMP_DIR_LOCATION/rocks

# Add s3 dag bundle to deployed airflow
[arg("bucket", long="bucket")]
[arg("access_key", long="access-key")]
[arg("secret_key", long="secret-key")]
[arg("path", long="path")]
[arg("endpoint", long="endpoint")]
[arg("tls_ca_chain_filepath", long="tls-ca-chain-filepath")]
[arg("app_name", long="app-name")]
airflow-add-s3-bundle bucket access_key="" secret_key="" path="" endpoint="" tls_ca_chain_filepath="" app_name="dag-bundle1":
    #!/usr/bin/bash
    set -eux

    if ([ -n "${access_key}" ] && [ -z "${secret_key}" ]) || ([ -z "${access_key}" ] && [ -n "${secret_key} "]); then
        echo "both access_key and secret_key need to be set, or not set together"
        exit 1
    fi

    juju deploy s3-integrator $app_name --channel 2/edge

    if [ -n "${access_key}" ]; then
        juju add-secret "${app_name}-creds" access-key="${access_key}" secret-key="${secret_key}"

        juju grant-secret "${app_name}-creds" $app_name

        secret_id=$(juju secrets | grep "${app_name}-creds" | awk '{print $1}')
    else
        secret_id=""
    fi

    tls_ca_chain=$(base64 -w0 $tls_ca_chain_filepath)

    juju config $app_name \
        bucket="${bucket}" \
        ${secret_id:+credentials="secret:$secret_id"} \
        ${path:+path=$path} \
        ${endpoint:+endpoint=$endpoint} \
        s3-uri-style="path" \
        ${tls_ca_chain:+tls-ca-chain=$tls_ca_chain}

    juju integrate $app_name airflow-coordinator-k8s

# Remove s3 dag bundle config
airflow-remove-s3-bundle app_name:
    #!/usr/bin/bash
    juju remove-application --force --no-prompt $app_name || true
    juju remove-secret ${app_name}-creds || true

# Add git dag bundle
[arg("path", long="path")]
[arg("tracking_ref", long="tracking-ref")]
[arg("authentication_method", long="authentication-method")]
[arg("username", long="username")]
[arg("personal_access_token", long="personal-access-token")]
[arg("ssh_private_key", long="ssh-private-key")]
[arg("strict_host_key_checking", long="strict-host-key-checking")]
[arg("app_name", long="app-name")]
airflow-add-git-bundle repository_url path="" tracking_ref="" authentication_method="" username="" personal_access_token="" ssh_private_key="" strict_host_key_checking="" app_name="git-bundle1":
    #!/usr/bin/bash
    set -eux

    juju deploy git-integrator $app_name --channel 1.0/edge

    secret_id=""

    if [ "$authentication_method" = "credentials" ]; then
        juju add-secret "${app_name}-creds" credentials-persona-access-token="${personal_access_token}"

        juju grant-secret "${app_name}-creds" $app_name

        secret_id=$(juju secrets | grep "${app_name}-creds" | awk '{print $1}')

    elif [ "$authentication_method" = "ssh" ]; then
        juju add-secret "${app_name}-creds" ssh-private-key="${ssh_private_key}"

        juju grant-secret "${app_name}-creds" $app_name

        secret_id=$(juju secrets | grep "${app_name}-creds" | awk '{print $1}')

    elif [ -n "$authentication_method" ]; then
        echo "Invalid authentication method"
        exit 1
    fi

    juju config $app_name \
        repository_url="${repository_url}" \
        ${path:+path=$path} \
        ${tracking_ref:+tracking_ref=$tracking_ref} \
        ${authentication_method:+authentication_method=$authentication_method} \
        ${username:+credentials_username=$credentials_username} \
        ${personal_access_token:+credentials_personal_access_token_secret="secret:${secret_id}"} \
        ${ssh_private_key:+ssh_private_key_secret="secret:${secret_id}"} \
        ${strict_host_key_checking:+ssh_strict_host_key_checking=$strict_host_key_checking}

    juju integrate $app_name airflow-coordinator-k8s

# Remove git dag bundle config
airflow-remove-git-bundle app_name:
    #!/usr/bin/bash
    juju remove-application --force --no-prompt $app_name || true
    juju remove-secret ${app_name}-creds || true
