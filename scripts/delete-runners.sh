#!/bin/bash
# Delete offline self-hosted runners from the Meshtastic org.
# These are usually failed runners (sometimes from infinite loop fail)
# or runners that no longer exist.

TOKEN=$1

RUNNER_LIST=$(curl -H "Authorization: ${TOKEN}" -H "Accept: application/vnd.github+json" https://api.github.com/orgs/meshtastic/actions/runners?per_page=100 | jq '[.runners[] | select(.status | contains("offline")) | {id: .id}]')

for id in $(echo "$RUNNER_LIST" | jq -r '.[] | @base64'); do
        _jq() {
                echo ${id} | base64 --decode | jq -r ${1}
        }
        echo $(_jq '.id')
        curl -X DELETE -H "Accept: application/vnd.github+json" -H "Authorization: ${TOKEN}"  https://api.github.com/orgs/meshtastic/actions/runners/$(_jq '.id')
done

