#!/usr/bin/env /bin/bash
set -euo pipefail

###
## GLOBAL VARIABLES
###
GITHUB_TOKEN=${GITHUB_TOKEN:-""}
GITHUB_USER=${GITHUB_USER:-""}
ORG=${ORG:-''}
API_URL_PREFIX=${API_URL_PREFIX:-'https://api.github.com'}
IFS=$'\n'

###
## FUNCTIONS
###

# Organization Members
  # You can only list 100 items per page, so you can only clone 100 at a time.
  # This function uses the API to calculate how many pages of members you have.
get_members_pagination () {
    members_pages=$(curl -I -u $GITHUB_USER:$GITHUB_TOKEN "${API_URL_PREFIX}/orgs/${ORG}/members?per_page=100" | grep -Eo '&page=\d+' | grep -Eo '[0-9]+' | tail -1;)
    echo "${members_pages:-1}"
}
  # This function uses the output from above and creates an array counting from 1->$ 
limit_members_pagination () {
  seq "$(get_members_pagination)"
}

# Users
import_users () {
for PAGE in $(limit_members_pagination); do

  for i in $(curl -s -u $GITHUB_USER:$GITHUB_TOKEN "${API_URL_PREFIX}/orgs/${ORG}/members?page=${PAGE}&per_page=100" | jq -r 'sort_by(.login) | .[] | .login'); do

  MEMBERSHIP_ROLE=$(curl -s -u $GITHUB_USER:$GITHUB_TOKEN "${API_URL_PREFIX}/orgs/${ORG}/memberships/${i}" | jq -r .role)

  # Terraform doesn't like '.' in resource names, so if one exists then replace it with a dash
  TERRAFORM_MEMBER_NAME=$(echo "${i}" | tr  "."  "-" | tr "-" "_" | tr '[:upper:]' '[:lower:]')
  
  cat >> ${ORG}-members.tf << EOF
resource "github_membership" "${TERRAFORM_MEMBER_NAME}" {
  username        = "${i}"
  role            = "${MEMBERSHIP_ROLE}"
}

EOF
    terraform import "github_membership.${TERRAFORM_MEMBER_NAME}" "${ORG}:${i}"
  done
done
}

import_users