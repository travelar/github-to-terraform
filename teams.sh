#!/usr/bin/env /bin/bash
set -euo pipefail

#debug
#set -x

###
## GLOBAL VARIABLES
###
GITHUB_TOKEN=${GITHUB_TOKEN:-""}
GITHUB_USER=${GITHUB_USER:-""}
ORG=${ORG:-''}
API_URL_PREFIX=${API_URL_PREFIX:-'https://api.github.com'}
IFS=$'\n'

get_team_pagination () {
    team_pages=$(curl -I -u $GITHUB_USER:$GITHUB_TOKEN "${API_URL_PREFIX}/orgs/${ORG}/teams?per_page=100" | grep -Eo '&page=\d+' | grep -Eo '[0-9]+' | tail -1;)
    echo "${team_pages:-1}"
}
  # This function uses the out from above and creates an array counting from 1->$ 
limit_team_pagination () {
  seq "$(get_team_pagination)"
}

get_team_ids () {
for PAGE in $(limit_team_pagination); do
  curl -s -u $GITHUB_USER:$GITHUB_TOKEN "${API_URL_PREFIX}/orgs/${ORG}/teams?${PAGE}&per_page=100" -H "Accept: application/vnd.github.hellcat-preview+json" | jq -r 'sort_by(.name) | .[] | .id'
done
}

import_teams () {
 for PAGE in $(limit_team_pagination); do
 
  for i in $(curl -s -u $GITHUB_USER:$GITHUB_TOKEN "${API_URL_PREFIX}/orgs/${ORG}/teams?page=1&per_page=100" -H "Accept: application/vnd.github.hellcat-preview+json" | jq -r 'sort_by(.name) | .[] | .id'); do
    TEAM_PAYLOAD=$(curl -s -u $GITHUB_USER:$GITHUB_TOKEN "${API_URL_PREFIX}/teams/${i}?page=1&per_page=100" -H "Accept: application/vnd.github.hellcat-preview+json")

    TEAM_NAME=$(echo "$TEAM_PAYLOAD" | jq -r .name)
    TEAM_NAME_NO_SPACE=`echo $TEAM_NAME | tr " " "_" | tr "/" "_"`
    TEAM_PRIVACY=$(echo "$TEAM_PAYLOAD" | jq -r .privacy)
    TEAM_DESCRIPTION=$(echo "$TEAM_PAYLOAD" | jq -r '.description | select(type == "string")')
    TEAM_PARENT_ID=$(echo "$TEAM_PAYLOAD" | jq -r .parent.id)

    # Terraform doesn't like '.' in resource names, so if one exists then replace it with a dash
    TEAM_NAME_LOWER=$(echo "${TEAM_NAME}" | tr " " "_" | tr "." "_" | tr "-" "_" | tr '[:upper:]' '[:lower:]')


    if [[ "${TEAM_PRIVACY}" == "closed" ]]; then
      cat >> ${ORG}-team-${TEAM_NAME_LOWER}.tf << EOF
resource "github_team" "${TEAM_NAME_LOWER}" {
  name           = "${TEAM_NAME}"
  description    = "${TEAM_DESCRIPTION}"
  privacy        = "closed"
  parent_team_id = ${TEAM_PARENT_ID}
}

EOF
    elif [[ "${TEAM_PRIVACY}" == "secret" ]]; then
      cat >> ${ORG}-team-${TEAM_NAME_LOWER}.tf << EOF
resource "github_team" "${TEAM_NAME_LOWER}" {
  name        = "${TEAM_NAME}"
  description = "${TEAM_DESCRIPTION}"
  privacy     = "secret"
}

EOF
    fi

    #terraform import "github_team.${TEAM_NAME_LOWER}" "${i}"
  done
 done
}

get_members_pagination () {
    members_pages=$(curl -I -u $GITHUB_USER:$GITHUB_TOKEN "${API_URL_PREFIX}/orgs/${ORG}/members?per_page=100" | grep -Eo '&page=\d+' | grep -Eo '[0-9]+' | tail -1;)
    echo "${members_pages:-1}"
}
  # This function uses the output from above and creates an array counting from 1->$ 
limit_members_pagination () {
  seq "$(get_members_pagination)"
}

# Team Memberships 
import_team_memberships () {
 for PAGE in $(limit_members_pagination); do

  for i in $(curl -s -u $GITHUB_USER:$GITHUB_TOKEN "${API_URL_PREFIX}/orgs/${ORG}/teams?page=1&per_page=100" -H "Accept: application/vnd.github.hellcat-preview+json" | jq -r 'sort_by(.name) | .[] | .id'); do
  
  TEAM_NAME=$(curl -s -u $GITHUB_USER:$GITHUB_TOKEN "${API_URL_PREFIX}/teams/${i}?page=1&per_page=100" -H "Accept: application/vnd.github.hellcat-preview+json" | jq -r .name | tr " " "_" | tr "/" "_")
  
    for j in $(curl -s -u $GITHUB_USER:$GITHUB_TOKEN "${API_URL_PREFIX}/teams/${i}/members?page=${PAGE}&per_page=100" -H "Accept: application/vnd.github.hellcat-preview+json" | jq -r .[].login); do
    
      TEAM_ROLE=$(curl -s -u $GITHUB_USER:$GITHUB_TOKEN "${API_URL_PREFIX}/teams/${i}/memberships/${j}?page=${PAGE}&per_page=100" -H "Accept: application/vnd.github.hellcat-preview+json" | jq -r .role)

      # Terraform doesn't like '.' in resource names, so if one exists then replace it with a dash
      TEAM_NAME_LOWER=$(echo "${TEAM_NAME}" | tr "-" "_" | tr '[:upper:]' '[:lower:]')
      MEMBER_NAME_LOWER=$(echo "${j}" | tr "-" "_" | tr '[:upper:]' '[:lower:]')

      if [[ "${TEAM_ROLE}" == "maintainer" ]]; then
        cat >> ${ORG}-team-memberships-${TEAM_NAME_LOWER}.tf << EOF
resource "github_team_membership" "${TEAM_NAME_LOWER}_${MEMBER_NAME_LOWER}" {
  username    = "${j}"
  team_id     = "${TEAM_ID}"
  role        = "maintainer"
}

EOF
      elif [[ "${TEAM_ROLE}" == "member" ]]; then
        cat >> ${ORG}-team-memberships-${TEAM_NAME_LOWER}.tf << EOF
resource "github_team_membership" "${TEAM_NAME_LOWER}_${MEMBER_NAME_LOWER}" {
  username    = "${j}"
  team_id     = "${TEAM_ID}"
  role        = "member"
}

EOF
      fi
      terraform import "github_team_membership.${TEAM_NAME_LOWER}_${MEMBER_NAME_LOWER}" "${i}:${j}"
    done
  done
 done
}

get_repo_pagination () {
    repo_pages=$(curl -I -u $GITHUB_USER:$GITHUB_TOKEN "${API_URL_PREFIX}/orgs/${ORG}/repos?per_page=100" | grep -Eo '&page=[0-9]+' | grep -Eo '[0-9]+' | tail -1;)
    echo "${repo_pages:-1}"
}
  # This function uses the output from above and creates an array counting from 1->$ 
limit_repo_pagination () {
  seq "$(get_repo_pagination)"
}

get_team_repos () {
   for PAGE in $(limit_repo_pagination); do

    for i in $(curl -s -u $GITHUB_USER:$GITHUB_TOKEN "${API_URL_PREFIX}/teams/${TEAM_ID}/repos?page=${PAGE}&per_page=100" | jq -r 'sort_by(.name) | .[] | .name'); do
    
    TERRAFORM_TEAM_REPO_NAME=$(echo "${i}" | tr  "."  "-" | tr "-" "_")
    TEAM_NAME=$(curl -s -u $GITHUB_USER:$GITHUB_TOKEN "${API_URL_PREFIX}/teams/${TEAM_ID}?page=${PAGE}&per_page=100" | jq -r .name | tr " " "_" | tr "/" "_" | tr "-" "_")

    PERMS_PAYLOAD=$(curl -s -u $GITHUB_USER:$GITHUB_TOKEN "${API_URL_PREFIX}/teams/${TEAM_ID}/repos/${ORG}/${i}?page=${PAGE}&per_page=100" -H "Accept: application/vnd.github.v3.repository+json")
    ADMIN_PERMS=$(echo "$PERMS_PAYLOAD" | jq -r .permissions.admin )
    PUSH_PERMS=$(echo "$PERMS_PAYLOAD" | jq -r .permissions.push )
    PULL_PERMS=$(echo "$PERMS_PAYLOAD" | jq -r .permissions.pull )
    #TEAM_ID=$(curl -s -u $GITHUB_USER:$GITHUB_TOKEN "${API_URL_PREFIX}/orgs/${ORG}/teams?${PAGE}&per_page=100" | jq -r .id)

      # Terraform doesn't like '.' in resource names, so if one exists then replace it with a dash
      TEAM_NAME_LOWER=$(echo "${TEAM_NAME}" | tr "-" "_" | tr '[:upper:]' '[:lower:]')
      TEAM_REPO_NAME_LOWER=$(echo "$TERRAFORM_TEAM_REPO_NAME" | tr "-" "_" | tr '[:upper:]' '[:lower:]' )


    if [[ "${ADMIN_PERMS}" == "true" ]]; then
      cat >> ${ORG}-team-${TEAM_NAME_LOWER}.tf << EOF
resource "github_team_repository" "${TEAM_NAME_LOWER}_${TEAM_REPO_NAME_LOWER}" {
  team_id    = "${TEAM_ID}"
  repository = "${i}"
  permission = "admin"
}

EOF
    elif [[ "${PUSH_PERMS}" == "true" ]]; then
      cat >> ${ORG}-team-${TEAM_NAME_LOWER}.tf << EOF
resource "github_team_repository" "${TEAM_NAME_LOWER}_${TEAM_REPO_NAME_LOWER}" {
  team_id    = "${TEAM_ID}"
  repository = "${i}"
  permission = "push"
}

EOF
    elif [[ "${PULL_PERMS}" == "true" ]]; then
      cat >> ${ORG}-team-${TEAM_NAME_LOWER}.tf << EOF
resource "github_team_repository" "${TEAM_NAME_LOWER}_${TEAM_REPO_NAME_LOWER}" {
  team_id    = "${TEAM_ID}"
  repository = "${i}"
  permission = "pull"
}

EOF
    fi
    terraform import "github_team_repository.${TEAM_NAME_LOWER}_${TEAM_REPO_NAME_LOWER}" "${TEAM_ID}:${i}"
  done
 done
}

import_team_repos () {
for TEAM_ID in $(get_team_ids); do
  get_team_repos
done
}

import_teams
import_team_repos
import_team_memberships