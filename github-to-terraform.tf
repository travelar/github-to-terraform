#!/usr/bin/env /bin/bash
set -euo pipefail

# Global Variables
# Set a token, a username, and the github organization name
GITHUB_TOKEN=${GITHUB_TOKEN:-""}
GITHUB_USER=${GITHUB_USER:-""}
ORG=${ORG:-""}
API_URL_PREFIX=${API_URL_PREFIX:-'https://api.github.com'}


# Import Functions
# public & private repos, members, teams, team membersips, and team repos

# Public Repos
import_public_repos () {
  
    for i in $(curl -s -u "$GITHUB_USER:$GITHUB_TOKEN" "${API_URL_PREFIX}/orgs/${ORG}/repos?type=public&page=1&per_page=500" | jq -r 'sort_by(.name) | .[] | .name'); do
      PUBLIC_REPO_PAYLOAD=$(curl -s -u $GITHUB_USER:$GITHUB_TOKEN "${API_URL_PREFIX}/repos/${ORG}/${i}" -H "Accept: application/vnd.github.mercy-preview+json")
  
      PUBLIC_REPO_DESCRIPTION=$(echo "$PUBLIC_REPO_PAYLOAD" | jq -r '.description | select(type == "string")' | sed "s/\"/'/g")
      PUBLIC_REPO_DOWNLOADS=$(echo "$PUBLIC_REPO_PAYLOAD" | jq -r .has_downloads)
      PUBLIC_REPO_WIKI=$(echo "$PUBLIC_REPO_PAYLOAD" | jq -r .has_wiki)
      PUBLIC_REPO_ISSUES=$(echo "$PUBLIC_REPO_PAYLOAD" | jq -r .has_issues)
      PUBLIC_REPO_ARCHIVED=$(echo "$PUBLIC_REPO_PAYLOAD" | jq -r .archived)
      PUBLIC_REPO_TOPICS=$(echo "$PUBLIC_REPO_PAYLOAD" | jq -r .topics)
      PUBLIC_REPO_PROJECTS=$(echo "$PUBLIC_REPO_PAYLOAD" | jq -r .has_projects)
      PUBLIC_REPO_MERGE_COMMIT=$(echo "$PUBLIC_REPO_PAYLOAD" | jq -r .allow_merge_commit)
      PUBLIC_REPO_REBASE_MERGE=$(echo "$PUBLIC_REPO_PAYLOAD" | jq -r .allow_rebase_merge)
      PUBLIC_REPO_SQUASH_MERGE=$(echo "$PUBLIC_REPO_PAYLOAD" | jq -r .allow_squash_merge)
      PUBLIC_REPO_AUTO_INIT=$(echo "$PUBLIC_REPO_PAYLOAD" | jq -r '.auto_init == true')
      PUBLIC_REPO_DEFAULT_BRANCH=$(echo "$PUBLIC_REPO_PAYLOAD" | jq -r .default_branch)
      PUBLIC_REPO_GITIGNORE_TEMPLATE=$(echo "$PUBLIC_REPO_PAYLOAD" | jq -r .gitignore_template)
      PUBLIC_REPO_LICENSE_TEMPLATE=$(echo "$PUBLIC_REPO_PAYLOAD" | jq -r '.license_template | select(type == "string")')
      PUBLIC_REPO_HOMEPAGE_URL=$(echo "$PUBLIC_REPO_PAYLOAD" | jq -r '.homepage | select(type == "string")')
     
      # Terraform doesn't like '.' in resource names, so if one exists then replace it with a dash
      TERRAFORM_PUBLIC_REPO_NAME=$(echo "${i}" | tr  "."  "-")

      cat >> ${ORG}-public-repos.tf << EOF
resource "github_repository" "${TERRAFORM_PUBLIC_REPO_NAME}" {
  name               = "${i}"
  topics             = ${PUBLIC_REPO_TOPICS}
  description        = "${PUBLIC_REPO_DESCRIPTION}"
  private            = false
  has_wiki           = ${PUBLIC_REPO_WIKI}
  has_projects       = ${PUBLIC_REPO_PROJECTS}
  has_downloads      = ${PUBLIC_REPO_DOWNLOADS}
  has_issues         = ${PUBLIC_REPO_ISSUES}
  archived           = ${PUBLIC_REPO_ARCHIVED}
  allow_merge_commit = ${PUBLIC_REPO_MERGE_COMMIT}
  allow_rebase_merge = ${PUBLIC_REPO_REBASE_MERGE}
  allow_squash_merge = ${PUBLIC_REPO_SQUASH_MERGE}
  auto_init          = ${PUBLIC_REPO_AUTO_INIT}
  gitignore_template = ${PUBLIC_REPO_GITIGNORE_TEMPLATE}
  license_template   = "${PUBLIC_REPO_LICENSE_TEMPLATE}"
  homepage_url       = "${PUBLIC_REPO_HOMEPAGE_URL}"
}
EOF

      terraform import "github_repository.${TERRAFORM_PUBLIC_REPO_NAME}" "${i}"
  done
}

# Private Repos
import_private_repos () {

    for i in $(curl -s -u $GITHUB_USER:$GITHUB_TOKEN "${API_URL_PREFIX}/orgs/${ORG}/repos?type=private&page=1&per_page=500" | jq -r 'sort_by(.name) | .[] | .name'); do
      PRIVATE_REPO_PAYLOAD=$(curl -s -u $GITHUB_USER:$GITHUB_TOKEN "${API_URL_PREFIX}/repos/${ORG}/${i}" -H "Accept: application/vnd.github.mercy-preview+json")

      PRIVATE_REPO_DESCRIPTION=$(echo "$PRIVATE_REPO_PAYLOAD" | jq -r '.description | select(type == "string")' | sed "s/\"/'/g")
      PRIVATE_REPO_DOWNLOADS=$(echo "$PRIVATE_REPO_PAYLOAD" | jq -r .has_downloads)
      PRIVATE_REPO_WIKI=$(echo "$PRIVATE_REPO_PAYLOAD" | jq -r .has_wiki)
      PRIVATE_REPO_ISSUES=$(echo "$PRIVATE_REPO_PAYLOAD" | jq -r .has_issues)
      PRIVATE_REPO_ARCHIVED=$(echo "$PRIVATE_REPO_PAYLOAD" | jq -r .archived)
      PRIVATE_REPO_TOPICS=$(echo "$PRIVATE_REPO_PAYLOAD" | jq -r .topics)
      PRIVATE_REPO_PROJECTS=$(echo "$PRIVATE_REPO_PAYLOAD" | jq -r .has_projects)
      PRIVATE_REPO_MERGE_COMMIT=$(echo "$PRIVATE_REPO_PAYLOAD" | jq -r .allow_merge_commit)
      PRIVATE_REPO_REBASE_MERGE=$(echo "$PRIVATE_REPO_PAYLOAD" | jq -r .allow_rebase_merge)
      PRIVATE_REPO_SQUASH_MERGE=$(echo "$PRIVATE_REPO_PAYLOAD" | jq -r .allow_squash_merge)
      PRIVATE_REPO_AUTO_INIT=$(echo "$PRIVATE_REPO_PAYLOAD" | jq -r .auto_init)
      PRIVATE_REPO_DEFAULT_BRANCH=$(echo "$PRIVATE_REPO_PAYLOAD" | jq -r .default_branch)
      PRIVATE_REPO_GITIGNORE_TEMPLATE=$(echo "$PRIVATE_REPO_PAYLOAD" | jq -r .gitignore_template)
      PRIVATE_REPO_LICENSE_TEMPLATE=$(echo "$PRIVATE_REPO_PAYLOAD" | jq -r '.license_template | select(type == "string")')
      PRIVATE_REPO_HOMEPAGE_URL=$(echo "$PRIVATE_REPO_PAYLOAD" | jq -r '.homepage | select(type == "string")')
     
      # Terraform doesn't like '.' in resource names, so if one exists then replace it with a dash
      TERRAFORM_PRIVATE_REPO_NAME=$(echo "${i}" | tr  "."  "-")

      cat >> ${ORG}-private-repos.tf << EOF
resource "github_repository" "${TERRAFORM_PRIVATE_REPO_NAME}" {
  name               = "${i}"
  private            = true
  description        = "${PRIVATE_REPO_DESCRIPTION}"
  has_wiki           = ${PRIVATE_REPO_WIKI}
  has_projects       = ${PRIVATE_REPO_PROJECTS}
  has_downloads      = ${PRIVATE_REPO_DOWNLOADS}
  has_issues         = ${PRIVATE_REPO_ISSUES}
  archived           = ${PRIVATE_REPO_ARCHIVED}
  topics             = ${PRIVATE_REPO_TOPICS}
  allow_merge_commit = ${PRIVATE_REPO_MERGE_COMMIT}
  allow_rebase_merge = ${PRIVATE_REPO_REBASE_MERGE}
  allow_squash_merge = ${PRIVATE_REPO_SQUASH_MERGE}
  auto_init          = ${PRIVATE_REPO_AUTO_INIT}
  gitignore_template = ${PRIVATE_REPO_GITIGNORE_TEMPLATE}
  license_template   = "${PRIVATE_REPO_LICENSE_TEMPLATE}"
  homepage_url       = "${PRIVATE_REPO_HOMEPAGE_URL}"
}

EOF
      terraform import "github_repository.${TERRAFORM_PRIVATE_REPO_NAME}" "${i}"
  done
}

# Users
import_members () {
  for i in $(curl -s -u $GITHUB_USER:$GITHUB_TOKEN "${API_URL_PREFIX}/orgs/${ORG}/members?page=1&per_page=500" | jq -r 'sort_by(.login) | .[] | .login'); do

  MEMBERSHIP_ROLE=$(curl -s -u $GITHUB_USER:$GITHUB_TOKEN "${API_URL_PREFIX}/orgs/${ORG}/memberships/${i}" | jq -r .role)

  cat >> ${ORG}-users.tf << EOF
resource "github_membership" "${i}" {
  username        = "${i}"
  role            = "${MEMBERSHIP_ROLE}"
}
EOF
    terraform import "github_membership.${i}" "${ORG}:${i}"
  done
}

# Teams
import_teams () {
  for i in $(curl -s -u $GITHUB_USER:$GITHUB_TOKEN "${API_URL_PREFIX}/orgs/${ORG}/teams?page=1&per_page=500" -H "Accept: application/vnd.github.hellcat-preview+json" | jq -r 'sort_by(.name) | .[] | .id'); do
    TEAM_PAYLOAD=$(curl -s -u $GITHUB_USER:$GITHUB_TOKEN "${API_URL_PREFIX}/teams/${i}?page=1&per_page=500" -H "Accept: application/vnd.github.hellcat-preview+json")

    TEAM_NAME=$(echo "$TEAM_PAYLOAD" | jq -r .name)
    TEAM_NAME_NO_SPACE=`echo $TEAM_NAME | tr " " "_" | tr "/" "_"`
    TEAM_PRIVACY=$(echo "$TEAM_PAYLOAD" | jq -r .privacy)
    TEAM_DESCRIPTION=$(echo "$TEAM_PAYLOAD" | jq -r '.description | select(type == "string")')
    TEAM_PARENT_ID=$(echo "$TEAM_PAYLOAD" | jq -r .parent.id)
  
    if [[ "${TEAM_PRIVACY}" == "closed" ]]; then
      cat >> ${ORG}-teams-${TEAM_NAME_NO_SPACE}.tf << EOF
resource "github_team" "${TEAM_NAME_NO_SPACE}" {
  name           = "${TEAM_NAME}"
  description    = "${TEAM_DESCRIPTION}"
  privacy        = "closed"
  parent_team_id = ${TEAM_PARENT_ID}
}
EOF
    elif [[ "${TEAM_PRIVACY}" == "secret" ]]; then
      cat >> ${ORG}-teams-${TEAM_NAME_NO_SPACE}.tf << EOF
resource "github_team" "${TEAM_NAME_NO_SPACE}" {
  name        = "${TEAM_NAME}"
  description = "${TEAM_DESCRIPTION}"
  privacy     = "secret"
}
EOF
    fi

    terraform import "github_team.${TEAM_NAME_NO_SPACE}" "${i}"
  done
}

# Team Memberships 
import_team_memberships () {
  for i in $(curl -s -u $GITHUB_USER:$GITHUB_TOKEN "${API_URL_PREFIX}/orgs/${ORG}/teams?page=1&per_page=500" -H "Accept: application/vnd.github.hellcat-preview+json" | jq -r 'sort_by(.name) | .[] | .id'); do
  
  TEAM_NAME=$(curl -s -u $GITHUB_USER:$GITHUB_TOKEN "${API_URL_PREFIX}/teams/${i}?page=1&per_page=500" -H "Accept: application/vnd.github.hellcat-preview+json" | jq -r .name | tr " " "_" | tr "/" "_")
  
    for j in $(curl -s -u $GITHUB_USER:$GITHUB_TOKEN "${API_URL_PREFIX}/teams/${i}/members?page=1&per_page=500" -H "Accept: application/vnd.github.hellcat-preview+json" | jq -r .[].login); do
    
      TEAM_ROLE=$(curl -s -u $GITHUB_USER:$GITHUB_TOKEN "${API_URL_PREFIX}/teams/${i}/memberships/${j}?page=1&per_page=500" -H "Accept: application/vnd.github.hellcat-preview+json" | jq -r .role)

      if [[ "${TEAM_ROLE}" == "maintainer" ]]; then
        cat >> ${ORG}-team-memberships-${TEAM_NAME}.tf << EOF
resource "github_team_membership" "${TEAM_NAME}-${j}" {
  username    = "${j}"
  team_id     = "\${github_team.${TEAM_NAME}.id}"
  role        = "maintainer"
}
EOF
      elif [[ "${TEAM_ROLE}" == "member" ]]; then
        cat >> ${ORG}-team-memberships-${TEAM_NAME}.tf << EOF
resource "github_team_membership" "${TEAM_NAME}-${j}" {
  username    = "${j}"
  team_id     = "\${github_team.${TEAM_NAME}.id}"
  role        = "member"
}
EOF
      fi
      terraform import "github_team_membership.${TEAM_NAME}-${j}" "${i}:${j}"
    done
  done
}


get_team_ids () {
  #echo   curl -s -u $GITHUB_USER:$GITHUB_TOKEN "${API_URL_PREFIX}/orgs/${ORG}/teams?page=1&per_page=500" -H "Accept: application/vnd.github.hellcat-preview+json" | jq -r 'sort_by(.name) | .[] | .id'
  curl -s -u $GITHUB_USER:$GITHUB_TOKEN "${API_URL_PREFIX}/orgs/${ORG}/teams?page=1&per_page=500" -H "Accept: application/vnd.github.hellcat-preview+json" | jq -r 'sort_by(.name) | .[] | .id'
}

get_team_repos () {

    for i in $(curl -s -u $GITHUB_USER:$GITHUB_TOKEN "${API_URL_PREFIX}/teams/${TEAM_ID}/repos?page=1&per_page=500" | jq -r 'sort_by(.name) | .[] | .name'); do
    
    TERRAFORM_TEAM_REPO_NAME=$(echo "${i}" | tr  "."  "-")
    TEAM_NAME=$(curl -s -u $GITHUB_USER:$GITHUB_TOKEN "${API_URL_PREFIX}/teams/${TEAM_ID}?page=1&per_page=500" | jq -r .name | tr " " "_" | tr "/" "_")

    PERMS_PAYLOAD=$(curl -s -u $GITHUB_USER:$GITHUB_TOKEN "${API_URL_PREFIX}/teams/${TEAM_ID}/repos/${ORG}/${i}?page=1&per_page=500" -H "Accept: application/vnd.github.v3.repository+json")
    ADMIN_PERMS=$(echo "$PERMS_PAYLOAD" | jq -r .permissions.admin )
    PUSH_PERMS=$(echo "$PERMS_PAYLOAD" | jq -r .permissions.push )
    PULL_PERMS=$(echo "$PERMS_PAYLOAD" | jq -r .permissions.pull )
  
    if [[ "${ADMIN_PERMS}" == "true" ]]; then
      cat >> ${ORG}-teams-${TEAM_NAME}.tf << EOF
resource "github_team_repository" "${TEAM_NAME}-${TERRAFORM_TEAM_REPO_NAME}" {
  team_id    = "${TEAM_ID}"
  repository = "${i}"
  permission = "admin"
}

EOF
    elif [[ "${PUSH_PERMS}" == "true" ]]; then
      cat >> ${ORG}-teams-${TEAM_NAME}.tf << EOF
resource "github_team_repository" "${TEAM_NAME}-${TERRAFORM_TEAM_REPO_NAME}" {
  team_id    = "${TEAM_ID}"
  repository = "${i}"
  permission = "push"
}

EOF
    elif [[ "${PULL_PERMS}" == "true" ]]; then
      cat >> ${ORG}-teams-${TEAM_NAME}.tf << EOF
resource "github_team_repository" "${TEAM_NAME}-${TERRAFORM_TEAM_REPO_NAME}" {
  team_id    = "${TEAM_ID}"
  repository = "${i}"
  permission = "pull"
}

EOF
    fi
    terraform import "github_team_repository.${TEAM_NAME}-${TERRAFORM_TEAM_REPO_NAME}" "${TEAM_ID}:${i}"
  done
}

import_team_repos () {
for TEAM_ID in $(get_team_ids); do
  get_team_repos
done
}

import_public_repos
import_private_repos
import_members
import_teams
import_team_memberships
import_team_repos