import "juju.justfile"

# Deploy airflow using juju commands
[arg("model", long="model")]
[arg("channel", long="channel")]
[arg("airflow_rock", long="airflow-rock")]
[arg("coordinator_charm", long="coordinator-charm")]
[arg("api_server_charm", long="api-server-charm")]
[arg("scheduler_charm", long="scheduler-charm")]
[arg("dag_processor_charm", long="dag-processor-charm")]
[arg("triggerer_charm", long="trigger-charm")]
deploy-airflow model="airflow" channel="3.1/edge" airflow_rock="" coordinator_charm="" api_server_charm="" scheduler_charm="" dag_processor_charm="" triggerer_charm="": (add-model model)
    #!/usr/bin/bash
    set -eux

    juju deploy postgresql-k8s --channel 14/stable --trust
    juju deploy pgbouncer-k8s --channel 1/stable --trust

    if [ -n "$airflow_rock" ]; then
        just start-local-registry
        just push-rock-to-local-registry $airflow_rock airflow dev
    fi

    juju deploy airflow-coordinator-k8s \
        --channel $channel \
        ${coordinator_charm:+--charm ${coordinator_charm}} \
        ${airflow_rock:+--resource airflow-coordinator-image=localhost:5000/airflow:dev}

    juju deploy airflow-api-server-k8s \
        --channel $channel \
        ${api_server_charm:+--charm $api_server_charm} \
        ${airflow_rock:+--resource airflow-coordinator-image=localhost:5000/airflow:dev}

    juju deploy airflow-scheduler-k8s \
        --channel $channel \
        ${scheduler_charm:+--charm $scheduler_charm} \
        ${airflow_rock:+--resource airflow-coordinator-image=localhost:5000/airflow:dev}

    juju deploy airflow-dag-processor-k8s \
        --channel $channel \
        ${dag_processor_charm:+--charm $dag_processor_charm} \
        ${airflow_rock:+--resource airflow-coordinator-image=localhost:5000/airflow:dev}

    juju deploy airflow-triggerer-k8s \
        --channel $channel \
        ${triggerer_charm:+--charm $triggerer_charm} \
        ${airflow_rock:+--resource airflow-coordinator-image=localhost:5000/airflow:dev}

    juju integrate postgresql-k8s pgbouncer-k8s

    juju integrate pgbouncer-k8s airflow-coordinator-k8s

    juju integrate airflow-api-server-k8s:airflow-api-server airflow-coordinator-k8s

    juju integrate airflow-coordinator-k8s:airflow-coordinator airflow-api-server-k8s
    juju integrate airflow-coordinator-k8s:airflow-coordinator airflow-scheduler-k8s
    juju integrate airflow-coordinator-k8s:airflow-coordinator airflow-dag-processor-k8s
    juju integrate airflow-coordinator-k8s:airflow-coordinator airflow-triggerer-k8s

    juju status --relations --storage

# Pack airflow-coordinator-charm
pack-airflow-coordinator:
    mkdir -p ~/charms

    charmcraft pack --project-dir ~/code/airflow-coordinator-k8s-operator

    mv airflow-coordinator*.charm ~/charms

# Pack airflow-rock
pack-airflow-rock version="3.1":
    #!/usr/bin/bash
    cd ~/code/airflow-rocks/${version}

    rockcraft pack

    mkdir -p ~/rocks
    mv airflow*.rock ~/rocks

# Add s3 dag bundle to deployed airflow
add-s3-bundle bucket access_key="" secret_key="" path="" endpoint="" tls_ca_chain_filepath="" alias="dag-bundle1":
    #!/usr/bin/bash
    set -eux

    if ([ -n "${access_key}" ] && [ -z "${secret_key}" ]) || ([ -z "${access_key}" ] && [ -n "${secret_key} "]); then
        echo "both access_key and secret_key need to be set, or not set together"
        exit 1
    fi

    juju deploy s3-integrator $alias --channel 2/edge

    if [ -n "${access_key}" ]; then
        juju add-secret "${alias}-creds" access-key="${access_key}" secret-key="${secret-key}"

        juju wait-for application $alias

        juju grant-secret $alias "${alias}-creds"
    fi

    juju config $alias \
        bucket="${bucket}" \
        ${access_key:+credentials="${alias}-creds"} \
        ${path:+path=$path} \
        ${endpoint:+endpoint=$endpoint} \
        s3-uri-style="path" \
        ${tls_ca_chain_filepath:+tls-ca-chain=$(base64 -w0 $tls_ca_chain_filepath)}

    juju integrate s3-integrator:s3 airflow-coordinator-k8s
