Build a SSL/TLS Certificate Test Lab using Docker Compose.
Everything must work by running: docker compose up -d

════════════════════════════════════════
OVERVIEW
════════════════════════════════════════

Two modes in one setup:

MODE 1 — Dev/Unit Test
  Static subdomains, each always serves one specific cert
  Used by developers to unit test against a fixed scenario
  Each subdomain = one cert case, always active

MODE 2 — QA Rotation
  Single endpoint that automatically rotates cert every N seconds
  Used by QA with a single app build pointing to one endpoint
  QA checks /status before running test to know current scenario
  Full URL: https://api.test.mxlabs.cloud:8443

════════════════════════════════════════
DOMAIN & DNS
════════════════════════════════════════

Base domain: mxlabs.cloud (registered on GoDaddy)

DNS records to configure (not part of Docker, just document it):
  A    test       → EC2_PUBLIC_IP
  A    *.test     → EC2_PUBLIC_IP

All subdomains resolve to the same EC2 instance.
Nginx/OpenResty uses server_name to route.

════════════════════════════════════════
CERTIFICATE REFERENCE (from real cert)
════════════════════════════════════════

All generated certs must mirror these properties from the
reference cert *.shongco.net:

  Key Algorithm : RSA 2048-bit
  Signature     : SHA256WithRSAEncryption
  Organization  : Ngern Tid Lor Public Company Limited
  Country       : TH
  State         : BANGKOK
  Locality      : Phaya Thai
  Issuer CN     : DigiCert Global G2 TLS RSA SHA256 2020 CA1
  Issuer Org    : DigiCert Inc
  Issuer Country: US
  Key Usage     : digitalSignature, keyEncipherment
  EKU           : serverAuth, clientAuth
  SAN           : DNS:*.{domain}, DNS:{domain}

════════════════════════════════════════
ENV FILE (.env)
════════════════════════════════════════

OCSP_HOST=PLACEHOLDER       # replace with EC2 public IP after deploy
BASE_DOMAIN=test.mxlabs.cloud
ROTATION_LOG=true

All scripts and configs must read from .env.
Never hardcode IP or domain anywhere.

════════════════════════════════════════
CERTIFICATE TEST CASES (10 cases)
════════════════════════════════════════

Generate all certs using a single shell script: gen-certs.sh
Script runs as cert-init container (initContainer pattern)
Only generates if certs don't already exist (idempotent)

┌─────────────────┬──────────────────────────────────────────────────┐
│ CASE NAME       │ HOW TO GENERATE                                  │
├─────────────────┼──────────────────────────────────────────────────┤
│ valid           │ RSA 2048, SHA256, SAN=*.test.mxlabs.cloud +      │
│                 │ test.mxlabs.cloud, keyUsage=digitalSignature+    │
│                 │ keyEncipherment, EKU=serverAuth+clientAuth,       │
│                 │ signed by Fake CA, valid 398 days                │
├─────────────────┼──────────────────────────────────────────────────┤
│ expired         │ Same as valid but:                               │
│                 │ notBefore=20230101000000Z                        │
│                 │ notAfter=20231231235959Z (already expired)       │
├─────────────────┼──────────────────────────────────────────────────┤
│ notyet          │ Same as valid but:                               │
│                 │ notBefore = now + 1 year                         │
│                 │ notAfter  = now + 2 years (not yet valid)        │
├─────────────────┼──────────────────────────────────────────────────┤
│ wronghost       │ RSA 2048, SHA256                                  │
│                 │ CN=evil.attacker.com                             │
│                 │ SAN=DNS:evil.attacker.com, DNS:*.attacker.com    │
│                 │ signed by Fake CA, valid 398 days                │
├─────────────────┼──────────────────────────────────────────────────┤
│ selfsigned      │ RSA 2048, SHA256                                  │
│                 │ SAN=*.test.mxlabs.cloud + test.mxlabs.cloud      │
│                 │ self-signed (issuer == subject, no CA)           │
├─────────────────┼──────────────────────────────────────────────────┤
│ untrustedca     │ Same as valid but:                               │
│                 │ signed by Rogue CA (separate CA, not in any      │
│                 │ trust store)                                     │
├─────────────────┼──────────────────────────────────────────────────┤
│ weakkey         │ RSA 1024-bit (weak), SHA256                       │
│                 │ SAN=*.test.mxlabs.cloud + test.mxlabs.cloud      │
│                 │ signed by Fake CA, valid 398 days                │
├─────────────────┼──────────────────────────────────────────────────┤
│ wrongusage      │ RSA 2048, SHA256                                  │
│                 │ keyUsage=digitalSignature only                   │
│                 │ EKU=emailProtection, codeSigning (no serverAuth) │
│                 │ signed by Fake CA, valid 398 days                │
├─────────────────┼──────────────────────────────────────────────────┤
│ wildcard        │ RSA 2048, SHA256                                  │
│                 │ CN=*.other-domain.com                            │
│                 │ SAN=DNS:*.other-domain.com, DNS:other-domain.com │
│                 │ signed by Fake CA, valid 398 days                │
├─────────────────┼──────────────────────────────────────────────────┤
│ revoked         │ Same as valid but:                               │
│                 │ embedded OCSP URL = http://${OCSP_HOST}:8080     │
│                 │ after generation: revoke it in CA index.txt      │
│                 │ so OCSP responder returns REVOKED                │
└─────────────────┴──────────────────────────────────────────────────┘

Also generate:
  - Fake CA cert/key  (CN = DigiCert Global G2 TLS RSA SHA256 2020 CA1)
  - Rogue CA cert/key (CN = Rogue CA, used only for untrustedca case)
  - OCSP signing cert/key (EKU = OCSPSigning, signed by Fake CA)
  - ca.mobileconfig   (Apple Configuration Profile for iOS CA install)
  - ca.crt            (for Android CA install)

At the end of gen-certs.sh, print the Fake CA SPKI hash:

  echo ""
  echo "════════════════════════════════════"
  echo " QA Build — Fake CA SPKI Hash"
  echo " Use this value for certificate pinning in QA app build"
  echo "════════════════════════════════════"
  openssl x509 -in certs/ca/ca.crt -pubkey -noout \
    | openssl pkey -pubin -outform DER \
    | openssl dgst -sha256 -binary \
    | base64

════════════════════════════════════════
DOCKER COMPOSE SERVICES
════════════════════════════════════════

── cert-init ──────────────────────────
  image   : alpine/openssl or debian with openssl
  role    : run gen-certs.sh once at startup
  pattern : initContainer (other services depend_on cert-init)
  volume  : mounts ./certs (read-write)
  exit    : exits 0 when done

── nginx (MODE 1 — Dev) ───────────────
  image   : nginx:alpine
  port    : 443
  role    : static subdomain per test case
  config  : /etc/nginx/conf.d/dev.conf
  volumes : ./certs (read-only), ./nginx/conf.d

  server_name routing:
    valid.test.mxlabs.cloud       → certs/server/valid.crt
    expired.test.mxlabs.cloud     → certs/server/expired.crt
    notyet.test.mxlabs.cloud      → certs/server/notyet.crt
    wronghost.test.mxlabs.cloud   → certs/server/wronghost.crt
    selfsigned.test.mxlabs.cloud  → certs/server/selfsigned.crt
    untrustedca.test.mxlabs.cloud → certs/server/untrustedca.crt
    weakkey.test.mxlabs.cloud     → certs/server/weakkey.crt
    wrongusage.test.mxlabs.cloud  → certs/server/wrongusage.crt
    wildcard.test.mxlabs.cloud    → certs/server/wildcard.crt
    revoked.test.mxlabs.cloud     → certs/server/revoked.crt

  each server block returns HTTP 200 JSON:
    { "case": "expired", "status": "ok", "message": "..." }

  use ssl_protocols TLSv1.2 TLSv1.3 on all blocks
  weakkey block must also allow TLSv1.2 with RSA-1024 ciphers

── openresty (MODE 2 — QA) ────────────
  image   : openresty/openresty:alpine
  port    : 8443 (avoid conflict with nginx port 443)
  role    : single endpoint, rotate cert by reading /state/current
  volumes : ./certs (read-only), ./state, ./openresty/lua

  Lua logic (ssl_certificate_by_lua_block):
    1. read file /state/current → get case name (e.g. "expired")
    2. map case name → cert path and key path
    3. ssl.clear_certs()
    4. load cert and key
    5. ssl.set_cert() / ssl.set_priv_key()

  server_name: api.test.mxlabs.cloud
  full QA endpoint URL: https://api.test.mxlabs.cloud:8443
  returns same JSON response as nginx blocks

── rotator ────────────────────────────
  image   : alpine
  role    : write current scenario to /state/current on schedule
  volumes : ./state (read-write)

  rotation schedule (write case name as plain text to /state/current):
    valid       → 300 seconds (5 minutes)
    expired     → 120 seconds (2 minutes)
    notyet      → 120 seconds
    wronghost   → 120 seconds
    selfsigned  → 120 seconds
    untrustedca → 120 seconds
    weakkey     → 120 seconds
    wrongusage  → 120 seconds
    wildcard    → 120 seconds
    revoked     → 120 seconds
    then loop back to valid

  on each rotation: log timestamp + case name to stdout
  total cycle = 23 minutes

── ocsp ───────────────────────────────
  image   : debian or alpine with openssl
  port    : 8080
  role    : OpenSSL OCSP responder
  command : openssl ocsp -port 8080 -index certs/ca/index.txt
              -CA certs/ca/ca.crt
              -rkey certs/ocsp/ocsp.key
              -rsigner certs/ocsp/ocsp.crt
              -nrequest 0  (run forever)
  volumes : ./certs (read-only)

── fileserver ─────────────────────────
  image   : nginx:alpine
  port    : 80
  role    :
    1. serve static files for device CA install
    2. serve status API for QA

  routes:
    GET /ca.crt          → certs/ca/ca.crt (download)
    GET /ca.mobileconfig → certs/ca/ca.mobileconfig (iOS profile)
    GET /status          → dynamic JSON via nginx + shell or
                           small python/node status service

  status JSON response:
    {
      "current_case"       : "expired",
      "next_case"          : "notyet",
      "next_in_seconds"    : 47,
      "duration_seconds"   : 120,
      "cycle_total_minutes": 23,
      "schedule": [
        { "case": "valid",       "duration_seconds": 300 },
        { "case": "expired",     "duration_seconds": 120 },
        { "case": "notyet",      "duration_seconds": 120 },
        { "case": "wronghost",   "duration_seconds": 120 },
        { "case": "selfsigned",  "duration_seconds": 120 },
        { "case": "untrustedca", "duration_seconds": 120 },
        { "case": "weakkey",     "duration_seconds": 120 },
        { "case": "wrongusage",  "duration_seconds": 120 },
        { "case": "wildcard",    "duration_seconds": 120 },
        { "case": "revoked",     "duration_seconds": 120 }
      ]
    }

════════════════════════════════════════
FILE STRUCTURE
════════════════════════════════════════

ssl-testlab/
├── .env                          ← OCSP_HOST, BASE_DOMAIN, ROTATION_LOG
├── docker-compose.yml
├── gen-certs.sh                  ← generate all certs (idempotent)
│                                    prints Fake CA SPKI hash at end
│
├── certs/                        ← generated by cert-init
│   ├── ca/
│   │   ├── ca.crt
│   │   ├── ca.key
│   │   ├── ca.mobileconfig
│   │   ├── index.txt             ← OpenSSL CA database
│   │   ├── index.txt.attr
│   │   ├── serial
│   │   └── crl.pem
│   ├── rogue-ca/
│   │   ├── rogue-ca.crt
│   │   └── rogue-ca.key
│   ├── ocsp/
│   │   ├── ocsp.crt
│   │   └── ocsp.key
│   └── server/
│       ├── valid.crt / valid.key
│       ├── expired.crt / expired.key
│       ├── notyet.crt / notyet.key
│       ├── wronghost.crt / wronghost.key
│       ├── selfsigned.crt / selfsigned.key
│       ├── untrustedca.crt / untrustedca.key
│       ├── weakkey.crt / weakkey.key
│       ├── wrongusage.crt / wrongusage.key
│       ├── wildcard.crt / wildcard.key
│       └── revoked.crt / revoked.key
│
├── nginx/
│   └── conf.d/
│       └── dev.conf              ← 10 server blocks for MODE 1
│
├── openresty/
│   ├── nginx.conf
│   └── lua/
│       └── select_cert.lua       ← read /state/current → pick cert
│
├── rotator/
│   └── rotate.sh                 ← loop through schedule, write to /state
│
├── fileserver/
│   ├── nginx.conf
│   └── www/
│       └── (ca.crt, ca.mobileconfig copied here by cert-init)
│
└── state/
    └── current                   ← plain text, e.g. "expired"

════════════════════════════════════════
STARTUP ORDER (depends_on)
════════════════════════════════════════

cert-init → (nginx, openresty, ocsp, fileserver, rotator)

cert-init must complete successfully before any other service starts.

════════════════════════════════════════
EC2 SECURITY GROUP — required open ports
════════════════════════════════════════

  22    → SSH
  80    → fileserver (CA download + status API)
  443   → nginx MODE 1 (Dev static subdomains)
  8080  → OCSP responder
  8443  → openresty MODE 2 (QA rotating endpoint)

════════════════════════════════════════
QUICK TEST COMMANDS (document in README)
════════════════════════════════════════

# Check current rotating scenario
curl http://test.mxlabs.cloud/status

# Test each static subdomain (skip TLS verify)
curl -kv https://valid.test.mxlabs.cloud
curl -kv https://expired.test.mxlabs.cloud
curl -kv https://revoked.test.mxlabs.cloud

# Test with Fake CA trust (strict verify)
curl --cacert ./certs/ca/ca.crt https://valid.test.mxlabs.cloud

# Test rotating QA endpoint
curl -kv https://api.test.mxlabs.cloud:8443

# Check cert details on any endpoint
echo | openssl s_client -connect expired.test.mxlabs.cloud:443 2>/dev/null \
  | openssl x509 -noout -dates -subject

# Test OCSP status for revoked cert
openssl ocsp \
  -issuer ./certs/ca/ca.crt \
  -cert ./certs/server/revoked.crt \
  -url http://${OCSP_HOST}:8080 \
  -resp_text

# Print Fake CA SPKI hash (for QA app pinning)
openssl x509 -in ./certs/ca/ca.crt -pubkey -noout \
  | openssl pkey -pubin -outform DER \
  | openssl dgst -sha256 -binary \
  | base64

════════════════════════════════════════
DEVICE SETUP (document in README)
════════════════════════════════════════

── iOS ────────────────────────────────

  Step 1: Install CA Profile
    Open Safari → http://test.mxlabs.cloud/ca.mobileconfig
    Tap "Allow" → "Install" → enter device passcode

  Step 2: Trust the CA
    Settings → General → About → Certificate Trust Settings
    → Enable "DigiCert Global G2 TLS RSA SHA256 2020 CA1"
    → Tap "Continue" to confirm

  Note: Both steps are required. Installing profile alone is not enough.

── Android ────────────────────────────

  Step 1: Download CA cert
    Browser → http://test.mxlabs.cloud/ca.crt → download

  Step 2: Install as CA
    Settings → Security → Encryption & Credentials
    → Install a Certificate → CA Certificate
    → Select ca.crt from Downloads

── Android App (API 24+) ──────────────

  User-installed CA is NOT trusted by apps by default on Android 7+.
  The app under test must include network_security_config.xml:

  File: res/xml/network_security_config.xml
    <network-security-config>
      <base-config>
        <trust-anchors>
          <certificates src="user"/>
          <certificates src="system"/>
        </trust-anchors>
      </base-config>
    </network-security-config>

  File: AndroidManifest.xml
    <application android:networkSecurityConfig="@xml/network_security_config">

════════════════════════════════════════
QA BUILD — CERTIFICATE PINNING GUIDE
════════════════════════════════════════

The QA app build must pin the Fake CA using SPKI pinning.
Do NOT pin the individual server cert (each case has a different key).
Do NOT bypass TLS validation — all cert checks must still run normally.

  What to pin  : Fake CA public key (SPKI hash)
  How to get it: run gen-certs.sh → SPKI hash printed at end
                 OR run the command below after certs are generated:

    openssl x509 -in ./certs/ca/ca.crt -pubkey -noout \
      | openssl pkey -pubin -outform DER \
      | openssl dgst -sha256 -binary \
      | base64

  Example output: "47DEQpj8HBSa+/TImW+5JCeuQeRkm5NMpJWZG3hSuFU="
  Embed this base64 value in the QA app build.

── iOS implementation ─────────────────

  Use custom SecTrust evaluation with Fake CA as anchor.
  Must still evaluate all standard validation (date, hostname, usage, OCSP).

  let certData = NSData(contentsOfFile: Bundle.main.path(
    forResource: "fake_ca", ofType: "crt")!)!
  let fakeCACert = SecCertificateCreateWithData(nil, certData)!

  // In URLSession delegate:
  func urlSession(_ session: URLSession,
    didReceive challenge: URLAuthenticationChallenge,
    completionHandler: @escaping (URLSession.AuthChallengeDisposition,
    URLCredential?) -> Void) {

    let trust = challenge.protectionSpace.serverTrust!
    SecTrustSetAnchorCertificates(trust, [fakeCACert] as CFArray)
    SecTrustSetAnchorCertificatesOnly(trust, true)
    // Standard evaluation still runs — expired/revoked/wronghost will fail
    var error: CFError?
    if SecTrustEvaluateWithError(trust, &error) {
      completionHandler(.useCredential,
        URLCredential(trust: trust))
    } else {
      completionHandler(.cancelAuthenticationChallenge, nil)
    }
  }

── Android implementation ─────────────

  Place fake_ca.crt in res/raw/fake_ca

  File: res/xml/network_security_config.xml
    <network-security-config>
      <base-config>
        <trust-anchors>
          <certificates src="@raw/fake_ca"/>
        </trust-anchors>
      </base-config>
    </network-security-config>

  No additional code needed.
  Android will trust only the Fake CA and still validate all cert properties.
  expired / revoked / wronghost cases will still fail as expected.

── Expected behavior per case ─────────

  valid       → ✅ connection succeeds
  expired     → ❌ SSL handshake fails  (CERTIFICATE_EXPIRED)
  notyet      → ❌ SSL handshake fails  (CERTIFICATE_NOT_YET_VALID)
  wronghost   → ❌ SSL handshake fails  (HOSTNAME_MISMATCH)
  selfsigned  → ❌ SSL handshake fails  (UNTRUSTED_ROOT)
  untrustedca → ❌ SSL handshake fails  (UNKNOWN_ROOT)
  weakkey     → ❌ SSL handshake fails  (HANDSHAKE_FAILED)
  wrongusage  → ❌ SSL handshake fails  (KEY_USAGE_INCOMPATIBLE)
  wildcard    → ❌ SSL handshake fails  (HOSTNAME_MISMATCH)
  revoked     → ❌ SSL handshake fails  (CERTIFICATE_REVOKED)
