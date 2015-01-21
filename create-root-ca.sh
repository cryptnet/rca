#!/bin/bash

[ -f basic.conf ] && source basic.conf || exit 1

#crlDistributionPoints	= URI:https://www.github.com/cryptnet/rca/raw/master/crls/$ENV::KEY_CRLFILE
RCA_NAME=`echo $2 | sed 's/[^a-zA-Z0-9_()[[:space:]]-]//g'`
RCA_FILENAME=`echo $2 | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9[[:space:]]-]//g' | sed 's/ /-/g'`

# RCA DIRS
RCA_CACERTDIR="${RCA_CERTDIR}/${RCA_FILENAME}"
RCA_CACRLDIR="${RCA_CRLDIR}/${RCA_FILENAME}"

# RCA FILES
RCA_VARFILE="${RCA_CONFDIR}/${RCA_FILENAME}.vars"
RCA_RANDFILE="${RCA_SECUREDIR}/${RCA_FILENAME}.rand"
RCA_KEYFILE="${RCA_SECUREDIR}/${RCA_FILENAME}.key"
RCA_INDEX="${RCA_CONFDIR}/${RCA_FILENAME}.index"
RCA_SERIAL="${RCA_CONFDIR}/${RCA_FILENAME}.serial"
RCA_CERTFILE="${RCA_CACERTSDIR}/${RCA_FILENAME}.crt"
RCA_CRLFILE="${RCA_CRLDIR}/${RCA_FILENAME}.crl"

print_usage()
{
	echo "usage: `basename $0` rsa|ecdsa [your root ca name here]"
	echo
}

cleanup()
{
	rm -rf ${RCA_RANDFILE} ${RCA_KEYFILE}
}

get_ca_vars()
{
	read -p "Country Name (2 letter code):" -r -n 2 RCA_COUNTRY
	echo
	read -p "Organization Name (eg, company):" -r RCA_ORG
	echo
	echo "The CA Variables contain:"
	echo "KEY_COUNTRY = $RCA_COUNTRY"
	echo "KEY_ORG = $RCA_ORG"
	echo "KEY_CN = $RCA_NAME"
	echo
	read -p "Thats right? (Y/n): " -r -n 1
	echo

	if [[ $REPLY =~ ^[Nn]$ ]]
	then
		cleanup
		echo "Creation abroaded."
		exit 0
	fi
}


generate_ca_varfile()
{
	echo "### automatic generated vars file on `date '+%d.%m.%y'` ###" > ${RCA_VARFILE}
	echo
	echo "export RCA_NAME=\"${RCA_NAME}\"" >> ${RCA_VARFILE}
	echo "export RCA_FILENAME=${RCA_FILENAME}" >> ${RCA_VARFILE}
	echo "export RCA_COUNTRY=${RCA_COUNTRY}" >> ${RCA_VARFILE}
	echo "export RCA_ORG=\"${RCA_ORG}\"" >> ${RCA_VARFILE}
	echo "export RCA_CN=\"${RCA_NAME}\"" >> ${RCA_VARFILE}
	echo "export RCA_CACERTDIR=${RCA_CERTDIR}/${RCA_FILENAME}" >> ${RCA_VARFILE}
	echo "export RCA_CACRLDIR=${RCA_CRLDIR}/${RCA_FILENAME}" >> ${RCA_VARFILE}
	echo "export RCA_VARFILE=${RCA_CONFDIR}/${RCA_FILENAME}.vars" >> ${RCA_VARFILE}
	echo "export RCA_RANDFILE=${RCA_SECUREDIR}/${RCA_FILENAME}.rand" >> ${RCA_VARFILE}
	echo "export RCA_KEYFILE=${RCA_SECUREDIR}/${RCA_FILENAME}.key" >> ${RCA_VARFILE}
	echo "export RCA_INDEX=${RCA_CONFDIR}/${RCA_FILENAME}.index" >> ${RCA_VARFILE}
	echo "export RCA_SERIAL=${RCA_CONFDIR}/${RCA_FILENAME}.serial" >> ${RCA_VARFILE}
	echo "export RCA_CERTFILE=${RCA_CACERTSDIR}/${RCA_FILENAME}.crt" >> ${RCA_VARFILE}
	echo "export RCA_CRLFILE=${RCA_CRLDIR}/${RCA_FILENAME}.crl" >> ${RCA_VARFILE}
}

create_ca_files()
{
	echo "01" > ${RCA_SERIAL}
	touch ${RCA_INDEX}
	[ ! -f ${RCA_CACERTDIR}/README ] && echo "Certificate store for signed ${RCA_NAME} certificates" > ${RCA_CACERTDIR}/README
	[ ! -f ${RCA_CACERTSDIR}/README ] && echo "CA Certificate store" > ${RCA_CACERTSDIR}/README
}

create_ca_dirs()
{
	# create secure dir if not exist
	[ ! -d ${RCA_SECUREDIR} ] && mkdir -p ${RCA_SECUREDIR}
	# create cert dirs if not exist
	[ ! -d ${RCA_CERTDIR} ] && mkdir -p ${RCA_CERTDIR}
	[ ! -d ${RCA_CACERTDIR} ] && mkdir -p ${RCA_CACERTDIR}
	[ ! -d ${RCA_CACERTSDIR} ] && mkdir -p ${RCA_CACERTSDIR}
	# create crl dirs if not exist
	[ ! -d ${RCA_CRLDIR} ] && mkdir -p ${RCA_CRLDIR}
	[ ! -d ${RCA_CACRLDIR} ] && mkdir -p ${RCA_CACRLDIR}
	# create csr dir if not exist
	[ ! -d ${RCA_CSRDIR} ] && mkdir -p ${RCA_CSRDIR}
}

if [[ "$1" == "" || "$2" == "" ]]
then
	print_usage
	exit 1
fi

# check if root ca already exists
if [ -f ${RCA_VARFILE} ]
then
	echo "Error: Root CA => "${RCA_NAME}" <= already exists"
	exit 1
fi

# create root ca dirs
create_ca_dirs

## generate random numbers
$OPENSSL rand -out ${RCA_RANDFILE} 4096

echo
echo "|======================|"
echo "| Generate private key |"
echo "|======================|"
echo

case "$1" in

	rsa)
		## generate RSA private ca key encrypted with aes 256
		$OPENSSL genpkey -out ${RCA_KEYFILE} -aes-256-cbc -algorithm RSA -pkeyopt rsa_keygen_bits:4096
		;;
	ecdsa)
		## generate EC private ca key encrypted with aes 256
		$OPENSSL ecparam -name sect571k1 -text -genkey | $OPENSSL ec -aes-256-cbc -out ${RCA_KEYFILE}
		;;
	*)
		print_usage
		exit 1
		;;
esac

## check if private ca key is created
if [ ! -f ${RCA_KEYFILE} ]
then
	echo "Error: private key creation error. Abroat."
	exit 1
fi

echo
echo "|===========================|"
echo "| Generate certificate file |"
echo "|===========================|"
echo

get_ca_vars
create_ca_files
generate_ca_varfile

# source the new generated var file
source ${RCA_VARFILE}

# generate the self signed root ca file
$OPENSSL req -out ${RCA_CERTFILE} -new -rand ${RCA_RANDFILE} -key ${RCA_KEYFILE} -sha1 -config ${RCA_CONFDIR}/root-ca.conf -x509 -days 7300 -batch

echo
echo "|===================|"
echo "| Generate crl file |"
echo "|===================|"
echo

# generate crl file
$OPENSSL ca -gencrl -config ${RCA_CONFDIR}/sub-ca.conf -out ${RCA_CRLFILE}

# print aut crl file
$OPENSSL crl -in ${RCA_CRLFILE} -noout -text

exit 0
