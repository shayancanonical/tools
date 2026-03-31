set export
set fallback

set dotenv-filename := "./configs.env"

import "microceph.justfile"
import "docker.justfile"
import "juju.justfile"
import "airflow.justfile"

[private]
default:
	just --list
