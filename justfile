set export
set fallback

set dotenv-load
set dotenv-filename := "microceph.env"

import "microceph.justfile"
import "docker.justfile"
import "juju.justfile"
import "airflow.justfile"

[private]
default:
	just --list
