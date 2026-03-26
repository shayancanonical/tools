# Add model, if it does not exist
add-model model:
    #!/usr/bin/bash

    if [ '$(juju models --format json | jq ''any(.models[]; .name == "admin/$model")'')' = "true" ]; then
        juju switch $model
    else
        juju add-model $model
    fi

# Destroy a model if it exists
destroy-model model force="" noprompt="":
    #!/usr/bin/bash
    set -eux

    if [ "$(juju models --format json | jq --arg model "admin/${model}" 'any(.models[]; .name == $model)')" = "true" ]; then
        extra_options="$([ -n "$force" ] && echo "--force --destroy-storage")"
        noprompt_options="$([ -n "$noprompt" ] && echo "--no-prompt")"
        juju destroy-model $extra_options $model
    fi
