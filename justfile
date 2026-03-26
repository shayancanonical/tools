set export
set fallback

import "microceph.justfile"
import "docker.justfile"
import "juju.justfile"
import "airflow.justfile"

[private]
default:
	just --list
