#!/bin/sh
set -eu

STATE_DIR="/state"
CURRENT_FILE="${STATE_DIR}/current"
ROTATION_FILE="${STATE_DIR}/rotation.json"
LOG_ROTATION="${ROTATION_LOG:-true}"

SCHEDULE="valid:300 expired:120 notyet:120 wronghost:120 selfsigned:120 untrustedca:120 weakkey:120 wrongusage:120 wildcard:120 revoked:120"
SCHEDULE_JSON='[
  {"case":"valid","duration_seconds":300},
  {"case":"expired","duration_seconds":120},
  {"case":"notyet","duration_seconds":120},
  {"case":"wronghost","duration_seconds":120},
  {"case":"selfsigned","duration_seconds":120},
  {"case":"untrustedca","duration_seconds":120},
  {"case":"weakkey","duration_seconds":120},
  {"case":"wrongusage","duration_seconds":120},
  {"case":"wildcard","duration_seconds":120},
  {"case":"revoked","duration_seconds":120}
]'

mkdir -p "${STATE_DIR}"

while :; do
  for entry in ${SCHEDULE}; do
    current_case="${entry%%:*}"
    duration="${entry##*:}"

    next_case="valid"
    found=0
    for candidate in ${SCHEDULE}; do
      candidate_case="${candidate%%:*}"
      if [ "${found}" -eq 1 ]; then
        next_case="${candidate_case}"
        break
      fi
      if [ "${candidate_case}" = "${current_case}" ]; then
        found=1
      fi
    done

    now_epoch="$(date -u +%s)"
    printf '%s\n' "${current_case}" > "${CURRENT_FILE}"
    cat > "${ROTATION_FILE}" <<EOF
{"current_case":"${current_case}","next_case":"${next_case}","duration_seconds":${duration},"started_at_epoch":${now_epoch},"cycle_total_minutes":23,"schedule":${SCHEDULE_JSON}}
EOF

    if [ "${LOG_ROTATION}" = "true" ]; then
      printf '%s case=%s duration=%s\n' "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" "${current_case}" "${duration}"
    fi

    sleep "${duration}"
  done
done
