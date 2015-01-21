#!/bin/bash

[ -f basic.conf ] && source basic.conf || exit 1

print_usage()
{
	echo "usage: `basename $0` [csr file in ${RCA_CSRDIR}]"
	echo
}

get_available_cas()
{	
	echo
	echo "Found these CA's in CA Storage:"
	echo
	for RCA_FILE in $(cd ${RCA_CACERTSDIR}; ls *.crt)
	do
		RCA_NAME=`$OPENSSL x509 -in ${RCA_CACERTSDIR}/${RCA_FILE} -noout -text | grep Subject: | sed 's/.*=//g'`
		RCA_ALGO=`$OPENSSL x509 -in ${RCA_CACERTSDIR}/${RCA_FILE} -noout -text | grep 'Public Key Algorithm:' | sed 's/.*: //g'`
		if [ "$RCA_ALGO" == "$CSR_ALGO" ]
		then
			let "COUNTER++"
			RCA_FILES[$COUNTER]="${RCA_FILE}"
			echo -e "\t$COUNTER) ${RCA_NAME}\t PKI Algorithm: ${RCA_ALGO}"
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
		RCA_FILE=${RCA_FILES[$REPLY]}
	else
		echo "Error: wrong input"
		exit 1
	fi
}

check_csr_file()
{
	if [ ! -f ${RCA_CSRDIR}/$1 ]
	then
		echo "Error: Input not a file."
		exit 1
	fi
	if [ "$(head -n 1 ${RCA_CSRDIR}/$1)" != "-----BEGIN CERTIFICATE REQUEST-----" ]
	then
		echo "Error: file isn't a valid CSR"
		exit 1
	fi
	CSR_SUBJECT=`$OPENSSL req -in ${RCA_CSRDIR}/$1 -noout -text | grep Subject: | sed 's/.*Subject://g' `
	CSR_ALGO=`$OPENSSL req -in ${RCA_CSRDIR}/$1 -noout -text | grep 'Public Key Algorithm:' | sed 's/.*: //g'`
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
	if [ "$RCA_FILE" != "" ]
	then
		RCA_VARFILE=${RCA_CONFDIR}/`echo $RCA_FILE | sed 's/\.crt//'`.vars
		if [ -f $RCA_VARFILE ]
		then
			source $RCA_VARFILE
			$OPENSSL ca -in ${RCA_CSRDIR}/$1 -config ${RCA_CONFDIR}/sub-ca.conf -out ${RCA_CACERTDIR}/`echo $1 | sed 's/\..*//'`.crt
		else
			echo "Error: no variable file available for CA!"
			exit 1
		fi
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
