# Add model, if it does not exist
add-model model:
    #!/usr/bin/bash

    if [ "$(juju models --format json | jq --arg model "admin/${model}" 'any(.models[]; .name == $model)')" = "true" ]; then
        juju switch $model
    else
        juju add-model $model
    fi

# Destroy a model if it exists
destroy-model model force="" noprompt="":
    #!/usr/bin/bash
    set -eux

    if [ "$(juju models --format json | jq --arg model "admin/${model}" 'any(.models[]; .name == $model)')" = "true" ]; then
        juju destroy-model $model ${force:+"--force --destroy-storage"} ${noprompt:+"--no-prompt"}
    fi

# Show juju status
juju-status:
    juju status --watch 1s --relations --storage

# Debug log
juju-debug-log replay="" include="":
    juju debug-log ${replay:+"--replay"} ${include:+"--include ${include}"}