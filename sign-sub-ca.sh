#!/bin/bash

print_usage()
{
	echo "usage: `basename $0` [path to csr file]"
	echo
}

get_available_cas()
{	
	echo
	echo "Found these CA's in CA Storage:"
	echo
	for ROOTCA_FILENAME in $(cd certs; ls *.crt)
	do
		ROOTCA_NAME=`openssl x509 -in certs/${ROOTCA_FILENAME} -noout -text | grep Subject: | sed 's/.*=//g'`
		ROOTCA_ALGO=`openssl x509 -in certs/${ROOTCA_FILENAME} -noout -text | grep 'Public Key Algorithm:' | sed 's/.*: //g'`
		if [ "$ROOTCA_ALGO" == "$CSR_ALGO" ]
		then
			let "COUNTER++"
			ROOTCA_FILES[$COUNTER]="${ROOTCA_FILENAME}"
			echo -e "\t$COUNTER) ${ROOTCA_NAME}\t PKI Algorithm: ${ROOTCA_ALGO}"
		fi
	done
	if [ -z "$COUNTER" ]
	then
		echo "Error: No available CA found for PKI Algo: $CSR_ALGO"
		exit 1
	fi

	echo
	read -p "Select one CA for singning CSR [1-$COUNTER]: " -r -n 1
	echo

	if [[ $REPLY =~ ^[0-9]*$ ]]
	then
		ROOTCA_FILENAME=${ROOTCA_FILES[$REPLY]}
	else
		echo "Error: wrong input"
		exit 1
	fi
}

check_csr_file()
{
	if [ ! -f $1 ]
	then
		echo "Error: Input not a file."
		exit 1
	fi
	if [ "$(head -n 1 $1)" != "-----BEGIN CERTIFICATE REQUEST-----" ]
	then
		echo "Error: file isn't a valid CSR"
		exit 1
	fi
	CSR_SUBJECT=`openssl req -in $1 -noout -text | grep Subject: | sed 's/.*Subject://g' `
	CSR_ALGO=`openssl req -in $1 -noout -text | grep 'Public Key Algorithm:' | sed 's/.*: //g'`
	echo
	echo "Information about the CSR to sign:"
	echo
	echo -e "\t Country: \t\t$(IFS=','; for i in ${CSR_SUBJECT}; do echo $i | grep C= | sed 's/.*C=//g'; done)"
	echo -e "\t State: \t\t$(IFS=','; for i in ${CSR_SUBJECT}; do echo $i | grep ST= | sed 's/.*ST=//g'; done)"
	echo -e "\t City: \t\t\t$(IFS=','; for i in ${CSR_SUBJECT}; do echo $i | grep L= | sed 's/.*L=//g'; done)"
	echo -e "\t Oragnisation: \t\t$(IFS=','; for i in ${CSR_SUBJECT}; do echo $i | grep O= | sed 's/.*O=//g'; done)"
	echo -e "\t Organisation Unit: \t$(IFS=','; for i in ${CSR_SUBJECT}; do echo $i | grep OU= | sed 's/.*OU=//g'; done)"
	echo -e "\t Common Name: \t\t$(IFS=','; for i in ${CSR_SUBJECT}; do echo $i | grep CN= | sed 's/.*CN=//g'; done)"
	echo -e "\t PKI Algorithm: \t${CSR_ALGO}"
	echo
}

create_signature()
{
	if [ "$ROOTCA_FILENAME" != "" ]
	then
		export ROOTCA_FILENAME=`echo $ROOTCA_FILENAME | sed 's/\.crt//'`
		openssl ca -in $1 -config conf/sub-ca.conf
	fi
}

if [ "$1" == "" ]
then
	print_usage
	exit 1
fi

check_csr_file $1
get_available_cas
create_signature $1

exit 0



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
openssl x509 -in certs/test-rsa-root-ca.crt -noout -text | grep 'Public Key Algorithm:' | sed 's/.*: //g'; done
-----BEGIN CERTIFICATE REQUEST-----
