# SSL Test Lab

This repository builds a self-contained SSL/TLS certificate test lab with Docker Compose.

## Summary

- `docker compose up -d` generates all certificates and starts:
- Static dev endpoints on `:443`
- Rotating QA endpoint on `:8443`
- OCSP responder on `:8080`
- CA download and status API on `:80`

## DNS

Configure these DNS records outside Docker:

- `A test -> EC2_PUBLIC_IP`
- `A *.test -> EC2_PUBLIC_IP`

All hostnames resolve to the same instance. Routing is handled by `server_name`.

## Environment

Set values in [.env](/d:/workspaces/@git-tiddaw-godev/VibeCode/certificate-test/.env):

```dotenv
OCSP_HOST=PLACEHOLDER
BASE_DOMAIN=test.mxlabs.cloud
ROTATION_LOG=true
```

Replace `OCSP_HOST` with the public IP or hostname that clients use to reach the OCSP responder.

## Start

```bash
docker compose up -d
```

The `cert-init` service runs first and exits successfully after generating certificates. All other services depend on it.

## Services

- `https://valid.<BASE_DOMAIN>`
- `https://expired.<BASE_DOMAIN>`
- `https://notyet.<BASE_DOMAIN>`
- `https://wronghost.<BASE_DOMAIN>`
- `https://selfsigned.<BASE_DOMAIN>`
- `https://untrustedca.<BASE_DOMAIN>`
- `https://weakkey.<BASE_DOMAIN>`
- `https://wrongusage.<BASE_DOMAIN>`
- `https://wildcard.<BASE_DOMAIN>`
- `https://revoked.<BASE_DOMAIN>`
- `https://api.<BASE_DOMAIN>:8443`
- `http://test.mxlabs.cloud/status`
- `http://test.mxlabs.cloud/ca.crt`
- `http://test.mxlabs.cloud/ca.mobileconfig`

## Rotation Schedule

- `valid`: 300 seconds
- `expired`: 120 seconds
- `notyet`: 120 seconds
- `wronghost`: 120 seconds
- `selfsigned`: 120 seconds
- `untrustedca`: 120 seconds
- `weakkey`: 120 seconds
- `wrongusage`: 120 seconds
- `wildcard`: 120 seconds
- `revoked`: 120 seconds

Total cycle time: 23 minutes.

## Quick Tests

```bash
curl http://test.mxlabs.cloud/status
curl -kv https://valid.test.mxlabs.cloud
curl -kv https://expired.test.mxlabs.cloud
curl -kv https://revoked.test.mxlabs.cloud
curl --cacert ./certs/ca/ca.crt https://valid.test.mxlabs.cloud
curl -kv https://api.test.mxlabs.cloud:8443
echo | openssl s_client -connect expired.test.mxlabs.cloud:443 2>/dev/null | openssl x509 -noout -dates -subject
openssl ocsp -issuer ./certs/ca/ca.crt -cert ./certs/server/revoked.crt -url http://${OCSP_HOST}:8080 -resp_text
openssl x509 -in ./certs/ca/ca.crt -pubkey -noout | openssl pkey -pubin -outform DER | openssl dgst -sha256 -binary | base64
```

## Device Setup

### iOS

1. Open Safari and visit `http://test.mxlabs.cloud/ca.mobileconfig`.
2. Install the profile.
3. Open `Settings -> General -> About -> Certificate Trust Settings`.
4. Enable trust for `DigiCert Global G2 TLS RSA SHA256 2020 CA1`.

### Android

1. Open `http://test.mxlabs.cloud/ca.crt`.
2. Install the certificate as a CA certificate.

For Android 7+ apps, allow user certificates or package the fake CA in `network_security_config.xml`.

## QA Pinning

Pin the Fake CA SPKI, not the leaf certificates. The generator prints the base64 SPKI hash at the end of `cert-init`.

## Notes

- The weak-key case lowers the Nginx OpenSSL security level for that hostname so the server can present the RSA-1024 certificate.
- The fileserver is implemented as a small Python HTTP service so `/status` can stay dynamic without adding a second sidecar.
