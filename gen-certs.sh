#!/bin/sh
set -eu

BASE_DOMAIN="${BASE_DOMAIN:?BASE_DOMAIN is required}"
OCSP_HOST="${OCSP_HOST:?OCSP_HOST is required}"

ROOT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
CERTS_DIR="${ROOT_DIR}/certs"
CA_DIR="${CERTS_DIR}/ca"
ROGUE_CA_DIR="${CERTS_DIR}/rogue-ca"
INTER_CA_DIR="${CERTS_DIR}/intermediate-ca"
OCSP_DIR="${CERTS_DIR}/ocsp"
SERVER_DIR="${CERTS_DIR}/server"
STATE_DIR="${ROOT_DIR}/state"

CA_CONFIG="${CA_DIR}/openssl-ca.cnf"
ROGUE_CA_CONFIG="${ROGUE_CA_DIR}/openssl-rogue-ca.cnf"
INTER_CA_CONFIG="${INTER_CA_DIR}/openssl-intermediate-ca.cnf"

mkdir -p "${CA_DIR}/newcerts" "${ROGUE_CA_DIR}/newcerts" "${INTER_CA_DIR}/newcerts" "${OCSP_DIR}" "${SERVER_DIR}" "${STATE_DIR}"

touch "${CA_DIR}/index.txt" "${ROGUE_CA_DIR}/index.txt" "${INTER_CA_DIR}/index.txt"
[ -f "${CA_DIR}/serial" ] || printf '1000\n' > "${CA_DIR}/serial"
[ -f "${ROGUE_CA_DIR}/serial" ] || printf '1000\n' > "${ROGUE_CA_DIR}/serial"
[ -f "${INTER_CA_DIR}/serial" ] || printf '1000\n' > "${INTER_CA_DIR}/serial"
[ -f "${CA_DIR}/index.txt.attr" ] || printf 'unique_subject = no\n' > "${CA_DIR}/index.txt.attr"
[ -f "${ROGUE_CA_DIR}/index.txt.attr" ] || printf 'unique_subject = no\n' > "${ROGUE_CA_DIR}/index.txt.attr"
[ -f "${INTER_CA_DIR}/index.txt.attr" ] || printf 'unique_subject = no\n' > "${INTER_CA_DIR}/index.txt.attr"

cat > "${CA_CONFIG}" <<EOF
[ ca ]
default_ca = CA_default

[ CA_default ]
dir = ${CA_DIR}
database = \$dir/index.txt
new_certs_dir = \$dir/newcerts
certificate = \$dir/ca.crt
private_key = \$dir/ca.key
serial = \$dir/serial
default_md = sha256
default_days = 398
default_crl_days = 30
policy = policy_loose
copy_extensions = copy
unique_subject = no

[ policy_loose ]
countryName = supplied
stateOrProvinceName = supplied
localityName = supplied
organizationName = supplied
commonName = supplied

[ req ]
default_bits = 2048
default_md = sha256
prompt = no
distinguished_name = ca_dn
string_mask = utf8only
req_extensions = v3_ca
x509_extensions = v3_ca

[ ca_dn ]
C = US
O = DigiCert Inc
CN = DigiCert Global G2 TLS RSA SHA256 2020 CA1

[ v3_ca ]
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always,issuer
basicConstraints = critical, CA:true, pathlen:1
keyUsage = critical, keyCertSign, cRLSign

[ ocsp_signing ]
basicConstraints = critical, CA:false
keyUsage = critical, digitalSignature
extendedKeyUsage = OCSPSigning
authorityKeyIdentifier = keyid,issuer
subjectKeyIdentifier = hash
EOF

cat > "${ROGUE_CA_CONFIG}" <<EOF
[ ca ]
default_ca = CA_default

[ CA_default ]
dir = ${ROGUE_CA_DIR}
database = \$dir/index.txt
new_certs_dir = \$dir/newcerts
certificate = \$dir/rogue-ca.crt
private_key = \$dir/rogue-ca.key
serial = \$dir/serial
default_md = sha256
default_days = 398
default_crl_days = 30
policy = policy_loose
copy_extensions = copy
unique_subject = no

[ policy_loose ]
countryName = supplied
stateOrProvinceName = supplied
localityName = supplied
organizationName = supplied
commonName = supplied

[ req ]
default_bits = 2048
default_md = sha256
prompt = no
distinguished_name = rogue_ca_dn
string_mask = utf8only
req_extensions = v3_ca
x509_extensions = v3_ca

[ rogue_ca_dn ]
C = US
O = Rogue CA
CN = Rogue CA

[ v3_ca ]
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always,issuer
basicConstraints = critical, CA:true, pathlen:0
keyUsage = critical, keyCertSign, cRLSign
EOF

if [ ! -f "${CA_DIR}/ca.crt" ] || [ ! -f "${CA_DIR}/ca.key" ]; then
  openssl req -x509 -newkey rsa:2048 -nodes \
    -config "${CA_CONFIG}" \
    -days 3650 \
    -keyout "${CA_DIR}/ca.key" \
    -out "${CA_DIR}/ca.crt"
fi

if [ ! -f "${ROGUE_CA_DIR}/rogue-ca.crt" ] || [ ! -f "${ROGUE_CA_DIR}/rogue-ca.key" ]; then
  openssl req -x509 -newkey rsa:2048 -nodes \
    -config "${ROGUE_CA_CONFIG}" \
    -days 3650 \
    -keyout "${ROGUE_CA_DIR}/rogue-ca.key" \
    -out "${ROGUE_CA_DIR}/rogue-ca.crt"
fi

cat > "${INTER_CA_CONFIG}" <<INTER_EOF
[ ca ]
default_ca = CA_default

[ CA_default ]
dir = ${INTER_CA_DIR}
database = \$dir/index.txt
new_certs_dir = \$dir/newcerts
certificate = \$dir/intermediate.crt
private_key = \$dir/intermediate.key
serial = \$dir/serial
default_md = sha256
default_days = 398
default_crl_days = 30
policy = policy_loose
copy_extensions = copy
unique_subject = no

[ policy_loose ]
countryName = supplied
stateOrProvinceName = supplied
localityName = supplied
organizationName = supplied
commonName = supplied

[ req ]
default_bits = 2048
default_md = sha256
prompt = no
distinguished_name = inter_ca_dn
string_mask = utf8only

[ inter_ca_dn ]
C = US
O = DigiCert Inc
CN = DigiCert Global G3 TLS RSA SHA256 2020 CA1

[ v3_intermediate_ca ]
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always,issuer
basicConstraints = critical, CA:true, pathlen:0
keyUsage = critical, keyCertSign, cRLSign
INTER_EOF

if [ ! -f "${INTER_CA_DIR}/intermediate.crt" ] || [ ! -f "${INTER_CA_DIR}/intermediate.key" ]; then
  openssl req -new -nodes -newkey rsa:2048 \
    -subj "/C=US/ST=California/L=San Jose/O=DigiCert Inc/CN=DigiCert Global G3 TLS RSA SHA256 2020 CA1" \
    -keyout "${INTER_CA_DIR}/intermediate.key" \
    -out "${INTER_CA_DIR}/intermediate.csr"

  openssl ca -batch -config "${CA_CONFIG}" \
    -extensions v3_intermediate_ca \
    -extfile "${INTER_CA_CONFIG}" \
    -in "${INTER_CA_DIR}/intermediate.csr" \
    -out "${INTER_CA_DIR}/intermediate.crt" \
    -days 1825
fi

if [ ! -f "${OCSP_DIR}/ocsp.crt" ] || [ ! -f "${OCSP_DIR}/ocsp.key" ]; then
  cat > "${OCSP_DIR}/ocsp.csr.cnf" <<EOF
[ req ]
default_bits = 2048
default_md = sha256
prompt = no
distinguished_name = dn

[ dn ]
C = US
ST = CALIFORNIA
L = MOUNTAIN VIEW
O = DigiCert Inc
CN = Fake OCSP Responder
EOF

  openssl req -new -nodes -newkey rsa:2048 \
    -config "${OCSP_DIR}/ocsp.csr.cnf" \
    -keyout "${OCSP_DIR}/ocsp.key" \
    -out "${OCSP_DIR}/ocsp.csr"

  openssl ca -batch -config "${CA_CONFIG}" \
    -extensions ocsp_signing \
    -in "${OCSP_DIR}/ocsp.csr" \
    -out "${OCSP_DIR}/ocsp.crt"
fi

subject_for_domain() {
  local cn="$1"
  cat <<EOF
/C=TH/ST=BANGKOK/L=Phaya Thai/O=Ngern Tid Lor Public Company Limited/CN=${cn}
EOF
}

write_case_extfile() {
  local extfile="$1"
  local usage="$2"
  local eku="$3"
  local alt_names="$4"
  local ocsp_url="${5:-}"

  cat > "${extfile}" <<EOF
[ server_cert ]
basicConstraints = critical, CA:false
keyUsage = critical, ${usage}
extendedKeyUsage = ${eku}
authorityKeyIdentifier = keyid,issuer
subjectKeyIdentifier = hash
subjectAltName = ${alt_names}
EOF

  if [ -n "${ocsp_url}" ]; then
    cat >> "${extfile}" <<EOF
authorityInfoAccess = OCSP;URI:${ocsp_url}
EOF
  fi
}

generate_leaf_signed() {
  local case_name="$1"
  local key_bits="$2"
  local subject_cn="$3"
  local alt_names="$4"
  local signer_config="$5"
  local key_usage="$6"
  local eku="$7"
  local startdate="${8:-}"
  local enddate="${9:-}"
  local ocsp_url="${10:-}"

  local key_file="${SERVER_DIR}/${case_name}.key"
  local csr_file="${SERVER_DIR}/${case_name}.csr"
  local crt_file="${SERVER_DIR}/${case_name}.crt"
  local ext_file="${SERVER_DIR}/${case_name}.ext.cnf"

  if [ -f "${key_file}" ] && [ -f "${crt_file}" ]; then
    return 0
  fi

  write_case_extfile "${ext_file}" "${key_usage}" "${eku}" "${alt_names}" "${ocsp_url}"

  openssl req -new -nodes -newkey "rsa:${key_bits}" \
    -subj "$(subject_for_domain "${subject_cn}")" \
    -keyout "${key_file}" \
    -out "${csr_file}"

  if [ -n "${startdate}" ] && [ -n "${enddate}" ]; then
    openssl ca -batch \
      -config "${signer_config}" \
      -extensions server_cert \
      -extfile "${ext_file}" \
      -in "${csr_file}" \
      -out "${crt_file}" \
      -startdate "${startdate}" \
      -enddate "${enddate}"
  else
    openssl ca -batch \
      -config "${signer_config}" \
      -extensions server_cert \
      -extfile "${ext_file}" \
      -in "${csr_file}" \
      -out "${crt_file}" \
      -days 398
  fi
}

generate_self_signed() {
  local key_file="${SERVER_DIR}/selfsigned.key"
  local crt_file="${SERVER_DIR}/selfsigned.crt"

  if [ -f "${key_file}" ] && [ -f "${crt_file}" ]; then
    return 0
  fi

  openssl req -x509 -newkey rsa:2048 -nodes -sha256 \
    -subj "$(subject_for_domain "*.${BASE_DOMAIN}")" \
    -days 398 \
    -addext "basicConstraints=critical,CA:false" \
    -addext "keyUsage=critical,digitalSignature,keyEncipherment" \
    -addext "extendedKeyUsage=serverAuth,clientAuth" \
    -addext "subjectAltName=DNS:*.${BASE_DOMAIN},DNS:${BASE_DOMAIN}" \
    -keyout "${key_file}" \
    -out "${crt_file}"
}

generate_mobileconfig() {
  local cert_b64
  cert_b64="$(base64 -w 0 "${CA_DIR}/ca.crt")"

  cat > "${CA_DIR}/ca.mobileconfig" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>PayloadContent</key>
  <array>
    <dict>
      <key>PayloadCertificateFileName</key>
      <string>ca.crt</string>
      <key>PayloadContent</key>
      <data>${cert_b64}</data>
      <key>PayloadDescription</key>
      <string>Installs the MX Labs fake CA for SSL test lab use.</string>
      <key>PayloadDisplayName</key>
      <string>DigiCert Global G2 TLS RSA SHA256 2020 CA1</string>
      <key>PayloadIdentifier</key>
      <string>cloud.mxlabs.ssl-testlab.ca</string>
      <key>PayloadType</key>
      <string>com.apple.security.root</string>
      <key>PayloadUUID</key>
      <string>1E390E06-7F8B-4A7A-B8A2-1A8C5979B8A1</string>
      <key>PayloadVersion</key>
      <integer>1</integer>
    </dict>
  </array>
  <key>PayloadDescription</key>
  <string>Installs the MX Labs fake CA for SSL test lab use.</string>
  <key>PayloadDisplayName</key>
  <string>MX Labs SSL Test Lab CA</string>
  <key>PayloadIdentifier</key>
  <string>cloud.mxlabs.ssl-testlab.profile</string>
  <key>PayloadRemovalDisallowed</key>
  <false/>
  <key>PayloadType</key>
  <string>Configuration</string>
  <key>PayloadUUID</key>
  <string>9645AFB7-3B3A-472D-93D8-C0B89A2F7A4F</string>
  <key>PayloadVersion</key>
  <integer>1</integer>
</dict>
</plist>
EOF
}

generate_leaf_signed "valid" "2048" "*.${BASE_DOMAIN}" "DNS:*.${BASE_DOMAIN},DNS:${BASE_DOMAIN}" \
  "${CA_CONFIG}" "digitalSignature, keyEncipherment" "serverAuth, clientAuth"

generate_leaf_signed "expired" "2048" "*.${BASE_DOMAIN}" "DNS:*.${BASE_DOMAIN},DNS:${BASE_DOMAIN}" \
  "${CA_CONFIG}" "digitalSignature, keyEncipherment" "serverAuth, clientAuth" \
  "20230101000000Z" "20231231235959Z"

NOW_EPOCH="$(date -u +%s)"
NOTYET_START="$(date -u -d "@$((NOW_EPOCH + 31536000))" +%Y%m%d%H%M%SZ)"
NOTYET_END="$(date -u -d "@$((NOW_EPOCH + 63072000))" +%Y%m%d%H%M%SZ)"
generate_leaf_signed "notyet" "2048" "*.${BASE_DOMAIN}" "DNS:*.${BASE_DOMAIN},DNS:${BASE_DOMAIN}" \
  "${CA_CONFIG}" "digitalSignature, keyEncipherment" "serverAuth, clientAuth" \
  "${NOTYET_START}" "${NOTYET_END}"

generate_leaf_signed "wronghost" "2048" "evil.attacker.com" "DNS:evil.attacker.com,DNS:*.attacker.com" \
  "${CA_CONFIG}" "digitalSignature, keyEncipherment" "serverAuth, clientAuth"

generate_self_signed

generate_leaf_signed "untrustedca" "2048" "*.${BASE_DOMAIN}" "DNS:*.${BASE_DOMAIN},DNS:${BASE_DOMAIN}" \
  "${ROGUE_CA_CONFIG}" "digitalSignature, keyEncipherment" "serverAuth, clientAuth"

generate_leaf_signed "weakkey" "1024" "*.${BASE_DOMAIN}" "DNS:*.${BASE_DOMAIN},DNS:${BASE_DOMAIN}" \
  "${CA_CONFIG}" "digitalSignature, keyEncipherment" "serverAuth, clientAuth"

generate_leaf_signed "wrongusage" "2048" "*.${BASE_DOMAIN}" "DNS:*.${BASE_DOMAIN},DNS:${BASE_DOMAIN}" \
  "${CA_CONFIG}" "digitalSignature" "emailProtection, codeSigning"

generate_leaf_signed "wildcard" "2048" "*.other-domain.com" "DNS:*.other-domain.com,DNS:other-domain.com" \
  "${CA_CONFIG}" "digitalSignature, keyEncipherment" "serverAuth, clientAuth"

generate_leaf_signed "revoked" "2048" "*.${BASE_DOMAIN}" "DNS:*.${BASE_DOMAIN},DNS:${BASE_DOMAIN}" \
  "${CA_CONFIG}" "digitalSignature, keyEncipherment" "serverAuth, clientAuth" \
  "" "" "http://${OCSP_HOST}:8080"

generate_leaf_signed "missingchain" "2048" "*.${BASE_DOMAIN}" "DNS:*.${BASE_DOMAIN},DNS:${BASE_DOMAIN}" \
  "${INTER_CA_CONFIG}" "digitalSignature, keyEncipherment" "serverAuth, clientAuth"

REVOKED_SERIAL="$(openssl x509 -in "${SERVER_DIR}/revoked.crt" -serial -noout | cut -d= -f2)"
if ! grep -Eq "^R[[:space:]].*[[:space:]]${REVOKED_SERIAL}[[:space:]]" "${CA_DIR}/index.txt"; then
  openssl ca -config "${CA_CONFIG}" -revoke "${SERVER_DIR}/revoked.crt"
fi

openssl ca -config "${CA_CONFIG}" -gencrl -out "${CA_DIR}/crl.pem"

generate_mobileconfig
printf 'valid\n' > "${STATE_DIR}/current"
cat > "${STATE_DIR}/rotation.json" <<EOF
{"current_case":"valid","next_case":"expired","duration_seconds":300,"started_at_epoch":$(date -u +%s),"cycle_total_minutes":25,"schedule":[{"case":"valid","duration_seconds":300},{"case":"expired","duration_seconds":120},{"case":"notyet","duration_seconds":120},{"case":"wronghost","duration_seconds":120},{"case":"selfsigned","duration_seconds":120},{"case":"untrustedca","duration_seconds":120},{"case":"weakkey","duration_seconds":120},{"case":"wrongusage","duration_seconds":120},{"case":"wildcard","duration_seconds":120},{"case":"revoked","duration_seconds":120},{"case":"missingchain","duration_seconds":120}]}
EOF

echo ""
echo "===================================="
echo " QA Build - Fake CA SPKI Hash"
echo " Use this value for certificate pinning in QA app build"
echo "===================================="
openssl x509 -in "${CA_DIR}/ca.crt" -pubkey -noout \
  | openssl pkey -pubin -outform DER \
  | openssl dgst -sha256 -binary \
  | base64
