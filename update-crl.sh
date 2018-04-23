#!/bin/sh

# Set needed variables (time format, CRL directory and list)
LC_TIME=C
CRL_DIR=/some/crl/path
CRL_LIST="http://www.sk.ee/crls/eeccrca/eeccrca.crl http://www.sk.ee/repository/crls/esteid2011.crl http://www.sk.ee/crls/esteid/esteid2015.crl http://www.sk.ee/repository/crls/eid2011.crl"

# Function to download CRL and convert from DER to PEM format
## $1 is $crl
## $2 is $CRL_DIR
## $3 is $crl_file
function get_crl () {
    curl -s $1 -o $2/$3.der
    openssl crl -in $2/$3.der -inform DER -out $2/$3
    rm $2/$3.der
}

# Check for CRL directory and create it if necessary
if [ ! -d $CRL_DIR ]; then
        mkdir -p $CRL_DIRL
fi

# Loop all CRL-s in list
for crl in $CRL_LIST; do

    # Extract CRL file name from URL using SED
    crl_file="$(echo $crl|sed 's,[a-z].*/,,')" 

    # Check if CRL file exist, if not then use function get_crl and set doreload variable to true
    if [ ! -f $CRL_DIR/$crl_file ]; then
        get_crl $crl $CRL_DIR $crl_file
        doreload=true
    fi

    # Set current time in unix timestamp
    crl_current_date=$(date "+%s")

    # Get CRL next update in unix timestamp
    crl_expire_date=$(date -d "$(date -d "$(openssl crl -in $CRL_DIR/$crl_file -nextupdate -noout|cut -d = -f 2)" "+%b %d %H:%M:%S %Y %Z")" "+%s")

    # If current unix timestamp is greater than crl expire unix timestamp, use get_crl function and set doreload variable to true
    if [ $crl_current_date -gt $crl_expire_date ]; then
        get_crl $crl $CRL_DIR $crl_file
        doreload=true
    fi

done

# If doreload variable is set to true, then remove all hash symlinks for crl files, recreate them and reload server
if [ "$doreload" == true ]; then
    rm $CRL_DIR/*.r0
    for crl in $CRL_LIST; do
        crl_file="$(echo $crl|sed 's,[a-z].*/,,')"
        ln -s $CRL_DIR/$crl_file $CRL_DIR/`openssl crl -hash -noout -in $CRL_DIR/$crl_file`.r0
    done
    service httpd reload
fi
