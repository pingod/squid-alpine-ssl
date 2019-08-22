#!/bin/sh

set -e

if [ -z "$CN" ]; then
	CN="squid.local"
fi

if [ -z "$O" ]; then
	O="squid"
fi

if [ -z "$OU" ]; then
	OU="squid"
fi

if [ -z "$C" ]; then
	C="US"
fi

if [ -z "$SQUID_USERNAME" ]; then
	SQUID_USERNAME="heaven"
fi

if [ -z "$SQUID_PASSWORD" ]; then
	SQUID_PASSWORD="echoinheaven"
fi

CHOWN=$(/usr/bin/which chown)
SQUID=$(/usr/bin/which squid)

prepare_folders() {
	echo "Preparing folders..."
	mkdir -p /etc/squid-cert/
	mkdir -p /var/cache/squid/
	mkdir -p /var/log/squid/
	"$CHOWN" -R squid:squid /etc/squid-cert/
	"$CHOWN" -R squid:squid /var/cache/squid/
	"$CHOWN" -R squid:squid /var/log/squid/
}

initialize_cache() {
	echo "Creating cache folder..."
	"$SQUID" -z

	sleep 5
}

create_cert() {
	if [ ! -f /etc/squid-cert/private.pem ]; then
		echo "Creating certificate..."
		openssl req -new -newkey rsa:2048 -sha256 -days 3650 -nodes -x509 \
			-extensions v3_ca -keyout /etc/squid-cert/private.pem \
			-out /etc/squid-cert/private.pem \
			-subj "/CN=$CN/O=$O/OU=$OU/C=$C" -utf8 -nameopt multiline,utf8

		openssl x509 -in /etc/squid-cert/private.pem \
			-outform DER -out /etc/squid-cert/CA.der

		openssl x509 -inform DER -in /etc/squid-cert/CA.der \
			-out /etc/squid-cert/CA.pem
	else
		echo "Certificate found..."
	fi
}

clear_certs_db() {
	echo "Clearing generated certificate db..."
	rm -rfv /var/cache/squid/ssl_db/
	/usr/lib/squid/security_file_certgen -c -s /var/cache/squid/ssl_db -M 4MB
	"$CHOWN" -R squid.squid /var/cache/squid/ssl_db
}

init_squid() {
	echo "Starting squid..."
	prepare_folders
	create_cert
	clear_certs_db
	initialize_cache
	htpasswd -bc /etc/squid/password  $SQUID_USERNAME $SQUID_PASSWORD
	exec "$SQUID" -NYCd 1 -f /etc/squid/squid.conf
}

init_squid
