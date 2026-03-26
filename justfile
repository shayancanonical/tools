set export
set fallback

set dotenv-load
set dotenv-filename := "microceph.env"

import "airflow.justfile"
import "microceph.justfile"

[private]
default:
	just --list
