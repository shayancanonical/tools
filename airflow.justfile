import "juju.justfile"

deploy-airflow model="test": (add-model "$model")
    #!/usr/bin/bash

    juju deploy airflow-coordinator-k8s
