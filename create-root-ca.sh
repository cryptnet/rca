#!/bin/bash

print_usage()
{
	echo "usage: `basename $0` rsa|ecdsa [your root ca name here]"
	echo
}

create_ca_vars()
{
	read -p "Country Name (2 letter code):" -r -n 2 KEY_COUNTRY
	echo
	read -p "Organization Name (eg, company):" -r KEY_ORG
	echo
	echo "The CA Variables contain:"
	echo "KEY_COUNTRY = $KEY_COUNTRY"
	echo "KEY_ORG = $KEY_ORG"
	echo "KEY_CN = $ROOTCA_NAME"
	echo
	read -p "Thats right? (Y/n): " -r -n 1
	echo

	if [[ $REPLY =~ ^[Nn]$ ]]
	then
		rm -rf private/${ROOTCA_FILENAME}.rand private/${ROOTCA_FILENAME}.key
		echo "Creation abroaded."
		exit 0
	fi

	echo "export KEY_COUNTRY=${KEY_COUNTRY}" >> conf/${ROOTCA_FILENAME}.vars
	echo "export KEY_ORG=\"${KEY_ORG}\"" >> conf/${ROOTCA_FILENAME}.vars
	echo "export KEY_CN=\"${ROOTCA_NAME}\"" >> conf/${ROOTCA_FILENAME}.vars
	echo "export KEY_CRLFILE=${ROOTCA_FILENAME}.crl" >> conf/${ROOTCA_FILENAME}.vars
}

if [[ "$1" == "" || "$2" == "" ]]
then
	print_usage
	exit 1
fi

ROOTCA_NAME=`echo $2 | sed 's/[^a-zA-Z0-9_()[[:space:]]-]//g'`
ROOTCA_FILENAME=`echo $2 | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9[[:space:]]-]//g' | sed 's/ /-/g'`

if [ -f conf/${ROOTCA_FILENAME}.conf ]
then
	echo "Error: Root CA => "${ROOTCA_NAME}" <= already exists"
	exit 1
fi

# create private dir if not exist
[ ! -d private ] && mkdir private

## generate random numbers
openssl rand -out private/${ROOTCA_FILENAME}.rand 4096

case $1 in

	rsa)
		## generate RSA private ca key encrypted with aes 256
		openssl genpkey -out private/${ROOTCA_FILENAME}.key -aes-256-cbc -algorithm RSA -pkeyopt rsa_keygen_bits:4096
		;;
	ecdsa)
		## generate EC private ca key encrypted with aes 256
		openssl ecparam -name sect571k1 -text -genkey | openssl ec -aes-256-cbc -out private/${ROOTCA_FILENAME}.key
		;;
	*)
		print_usage
		exit 1
		;;
esac

## check if RSA private ca key is created
if [ ! -f private/${ROOTCA_FILENAME}.key ]
then
	echo "Error: Private key creation error. Abroat."
	exit 1
fi

create_ca_vars
source conf/${ROOTCA_FILENAME}.vars

[ ! -d certs ] && mkdir certs

openssl req -out certs/${ROOTCA_FILENAME}.crt -new -rand private/${ROOTCA_FILENAME}.rand -key private/${ROOTCA_FILENAME}.key -sha1 -config conf/root-ca.conf -x509 -days 7300 -batch

exit 0
