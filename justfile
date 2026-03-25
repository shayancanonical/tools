set export
set fallback

[private]
default:
	just --list

# Get the microceph node IP
microceph-node-ip:
	#!/usr/bin/bash
	echo "$(sudo microceph status | head -n 2 | tail -n 1 | awk '{print $3}' | tr -d '()')"

# Create certificates for microceph
set-up-microceph-certs:
	#!/usr/bin/bash

	if [ ! -d "microceph_certs" ]; then
		host_ip="(just microceph-node-ip)"

		mkdir microceph_certs

		openssl genrsa -out ./microceph_certs/ca.key

		openssl req \
			-x509 \
			-new \
			-nodes \
			-key ./microceph_certs/ca.key \
			-days 1024 \
			-out ./microceph_certs/ca.crt \
			-outform PEM \
			-subj /C=US/ST=Denial/L=Springfield/O=Dis/CN=www.example.com

		openssl genrsa -out ./microceph_certs/server.key 2048

		openssl req \
			-new \
			-key ./microceph_certs/server.key \
			-out ./microceph_certs/server.csr \
			-subj /C=US/ST=Denial/L=Springfield/O=Dis/CN=www.example.com

		echo "subjectAltName = IP:$host_ip" > ./extfile.cnf

		openssl x509 \
			-req \
			-in ./microceph_certs/server.csr \
			-CA ./microceph_certs/ca.crt \
			-CAkey ./microceph_certs/ca.key \
			-CAcreateserial \
			-out ./microceph_certs/server.crt \
			-days 365 \
			-extfile ./microceph_certs/extfile.cnf
	fi

# Install and bootstrap microceph
install-and-bootstrap-microceph:
	#!/usr/bin/bash
	if [ "$(sudo snap list microceph | wc -l)" -ne "2" ]; then
		sudo snap install microceph --channel squid/stable
		sudo microceph cluster bootstrap
		sudo microceph disk add loop,1G,3
	fi

# Enable radosgw if it is not already
enable-radosgw:
	#!/usr/bin/bash
	if [ "$(sudo microceph status | grep Services | grep rgw | wc -l)" -ne "1" ]; then
		just setup-microceph-certs

		sudo microceph enable rgw \
			--ssl-certificate="$(base64 -w0 ./microceph_certs/server.crt)" \
			--ssl-private-key="$(base64 -w0 ./microceph_certs/server.key)"
	fi

# Set up microceph user
setup-microceph-user username access_key="foo" secret_key="bar" caps="bucket=*;users=read;usage=*;metadata=*":
	#!/usr/bin/bash
	if [ "$(sudo microceph.radosgw-admin user list | grep $username | wc -l)" -ne "1" ]; then
		sudo microceph.radosgw-admin user create \
			--uid $username \
			--display-name $username \
			--access-key $access_key \
			--secret-key $secret_key

		sudo microceph.radosgw-admin caps add \
			--uid $username \
			--caps $caps
	fi

# Set up microceph for local usage
set-up-microceph:
	just install-and-bootstrap-microceph

	just setup-microceph-certs

	just setup-microceph-user test

	sudo microceph status
