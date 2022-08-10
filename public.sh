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

set -x

###
## FUNCTIONS
###

# Public Repos
  # You can only list 100 items per page, so you can only clone 100 at a time.
  # This function uses the API to calculate how many pages of public repos you have.
get_public_pagination () {
    public_pages=$(curl -I -u $GITHUB_USER:$GITHUB_TOKEN "${API_URL_PREFIX}/orgs/${ORG}/repos?type=public&per_page=100" | grep -Eo '&page=[0-9]+' | grep -Eo '[0-9]+' | tail -1;)
    echo "${public_pages:-1}"
}
  # This function uses the output from above and creates an array counting from 1->$ 
limit_public_pagination () {
  seq "$(get_public_pagination)"
}

  # Now lets import the repos, starting with page 1 and iterating through the pages
import_public_repos () {
  for PAGE in $(limit_public_pagination); do

    for i in $(curl -s -u $GITHUB_USER:$GITHUB_TOKEN "${API_URL_PREFIX}/orgs/${ORG}/repos?type=public&page=${PAGE}&per_page=100" | jq -r 'sort_by(.name) | .[] | .name'); do
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
      PUBLIC_REPO_DELETE_MERGE=$(echo "$PUBLIC_REPO_PAYLOAD" | jq -r .delete_branch_on_merge)
      PUBLIC_REPO_AUTO_INIT=$(echo "$PUBLIC_REPO_PAYLOAD" | jq -r '.auto_init == true')      PUBLIC_REPO_DEFAULT_BRANCH=$(echo "$PUBLIC_REPO_PAYLOAD" | jq -r .default_branch)
      PUBLIC_REPO_GITIGNORE_TEMPLATE=$(echo "$PUBLIC_REPO_PAYLOAD" | jq -r .gitignore_template)
      PUBLIC_REPO_LICENSE_TEMPLATE=$(echo "$PUBLIC_REPO_PAYLOAD" | jq -r '.license_template | select(type == "string")')
      PUBLIC_REPO_HOMEPAGE_URL=$(echo "$PUBLIC_REPO_PAYLOAD" | jq -r '.homepage | select(type == "string")')
     
      # Terraform doesn't like '.' in resource names, so if one exists then replace it with a dash
      TERRAFORM_PUBLIC_REPO_NAME=$(echo "${i}" | tr  "."  "-" | tr "-" "_" | tr '[:upper:]' '[:lower:]')

      cat >> ${ORG}-public-repos.tf << EOF
resource "github_repository" "${TERRAFORM_PUBLIC_REPO_NAME}" {
  name                    = "${i}"
  topics                  = ${PUBLIC_REPO_TOPICS}
  description             = "${PUBLIC_REPO_DESCRIPTION}"
  private                 = false
  has_wiki                = ${PUBLIC_REPO_WIKI}
  has_projects            = ${PUBLIC_REPO_PROJECTS}
  has_downloads           = ${PUBLIC_REPO_DOWNLOADS}
  has_issues              = ${PUBLIC_REPO_ISSUES}
  archived                = ${PUBLIC_REPO_ARCHIVED}
  allow_merge_commit      = ${PUBLIC_REPO_MERGE_COMMIT}
  allow_rebase_merge      = ${PUBLIC_REPO_REBASE_MERGE}
  allow_squash_merge      = ${PUBLIC_REPO_SQUASH_MERGE}
  delete_branch_on_merge  = ${PUBLIC_REPO_DELETE_MERGE}
  auto_init               = ${PUBLIC_REPO_AUTO_INIT}
  vulnerability_alerts    = ${PUBLIC_REPO_VULN_ALERTS}
  gitignore_template      = ${PUBLIC_REPO_GITIGNORE_TEMPLATE}
  license_template        = "${PUBLIC_REPO_LICENSE_TEMPLATE}"
  homepage_url            = "${PUBLIC_REPO_HOMEPAGE_URL}"
}

EOF

      #terraform import "github_repository.${TERRAFORM_PUBLIC_REPO_NAME}" "${i}"
    done
  done
}

import_public_repo_branches () {

  for PAGE in $(limit_public_pagination); do

    for i in $(curl -s -u $GITHUB_USER:$GITHUB_TOKEN "${API_URL_PREFIX}/orgs/${ORG}/repos?type=public&page=${PAGE}&per_page=100" | jq -r 'sort_by(.name) | .[] | .name'); do
    for j in $(curl -s -u $GITHUB_USER:$GITHUB_TOKEN "${API_URL_PREFIX}/repos/${ORG}/${i}/branches?protected=true&page=${PAGE}&per_page=100" | jq -r 'sort_by(.name) | .[] | .name'); do      
      PUBLIC_BRANCH_PAYLOAD=$(curl -s -u $GITHUB_USER:$GITHUB_TOKEN "${API_URL_PREFIX}/repos/${ORG}/${i}/branches/${j}?page=${PAGE}&per_page=100" -H "Accept: application/vnd.github+json")
      PUBLIC_BRANCH_PROTECTIONS=$(curl -s -u $GITHUB_USER:$GITHUB_TOKEN "${API_URL_PREFIX}/repos/${ORG}/${i}/branches/${j}/protection" -H "Accept: application/vnd.github+json")
      
      PUBLIC_REPO_PAYLOAD=$(curl -s -u $GITHUB_USER:$GITHUB_TOKEN "${API_URL_PREFIX}/repos/${ORG}/${i}" -H "Accept: application/vnd.github.mercy-preview+json")

      PROTECTED_BRANCH_ENFORCE_ADMINS=$(echo "$PUBLIC_REPO_PAYLOAD" | jq -r .enforce_admins.enabled) 

      # required_pull_request_review
      PUBLIC_BRANCH_DISMISS_STALE_REVIEWS=$(curl -s -u $GITHUB_USER:$GITHUB_TOKEN "${API_URL_PREFIX}/repos/${ORG}/${i}/branches/${j}/protection/required_pull_request_reviews" | jq -r .dismiss_stale_reviews)
      PUBLIC_BRANCH_REVIEW_COUNT=$(curl -s -u $GITHUB_USER:$GITHUB_TOKEN "${API_URL_PREFIX}/repos/${ORG}/${i}/branches/${j}/protection/required_pull_request_reviews" | jq -r .required_approving_review_count)
      PUBLIC_BRANCH_CODE_OWNER_REVIEW=$(curl -s -u $GITHUB_USER:$GITHUB_TOKEN "${API_URL_PREFIX}/repos/${ORG}/${i}/branches/${j}/protection/required_pull_request_reviews" | jq -r .require_code_owner_reviews)

      PROTECTED_BRANCH_REQUIRED_PULL_REQUEST_REVIEWS_USERS=$(echo "$PUBLIC_REPO_PAYLOAD" | jq -r '.required_pull_request_reviews.users[]?.login')
      PROTECTED_BRANCH_REQUIRED_PULL_REQUEST_REVIEWS_TEAMS=$(echo "$PUBLIC_REPO_PAYLOAD" | jq -r '.required_pull_request_reviews.team[]?.slug')
      PROTECTED_BRANCH_RESTRICTIONS_USERS=$(echo "$PUBLIC_REPO_PAYLOAD" | jq -r '.restrictions.users[]?.login')
      PROTECTED_BRANCH_RESTRICTIONS_TEAMS=$(echo "$PUBLIC_REPO_PAYLOAD" | jq -r '.restrictions.teams[]?.slug') 

      # convert bash arrays into csv list
      PROTECTED_BRANCH_RESTRICTIONS_USERS_LIST=$(echo "${PROTECTED_BRANCH_RESTRICTIONS_USERS}" | tr  " "  ", ")
      PROTECTED_BRANCH_RESTRICTIONS_TEAMS_LIST=$(echo "${PROTECTED_BRANCH_RESTRICTIONS_TEAMS}" | tr  " "  ", ")
      PROTECTED_BRANCH_REQUIRED_PULL_REQUEST_REVIEWS_USERS_LIST=$(echo "${PROTECTED_BRANCH_REQUIRED_PULL_REQUEST_REVIEWS_USERS}" | tr  " "  ", ")
      PROTECTED_BRANCH_REQUIRED_PULL_REQUEST_REVIEWS_TEAMS_LIST=$(echo "${PROTECTED_BRANCH_REQUIRED_PULL_REQUEST_REVIEWS_TEAMS}" | tr  " "  ", ")

      # required_status_checks
      PUBLIC_BRANCH_STRICT=$(curl -s -u $GITHUB_USER:$GITHUB_TOKEN "${API_URL_PREFIX}/repos/${ORG}/${i}/branches/${j}/protection/required_status_checks" | jq -r .strict)
      PUBLIC_BRANCH_CONTEXTS=$(curl -s -u $GITHUB_USER:$GITHUB_TOKEN "${API_URL_PREFIX}/repos/${ORG}/${i}/branches/${j}/protection/required_status_checks" | jq -r .contexts)
     
      # Terraform doesn't like '.' in resource names, so if one exists then replace it with a dash
      TERRAFORM_PUBLIC_REPO_NAME=$(echo "${i}" | tr  "."  "-" | tr "-" "_" | tr '[:upper:]' '[:lower:]')

      cat >> ${ORG}-public-repos.tf << EOF
resource "github_branch_protection_v3" "${TERRAFORM_PUBLIC_REPO_NAME}_${j}" {
  repository         = "${i}"
  branch             = "${j}"
  enforce_admins = ${PROTECTED_BRANCH_ENFORCE_ADMINS}

  required_status_checks {
    strict = ${PUBLIC_BRANCH_STRICT}
    contexts = ${PUBLIC_BRANCH_CONTEXTS}
  }

  required_pull_request_reviews {
    dismiss_stale_reviews = ${PUBLIC_BRANCH_DISMISS_STALE_REVIEWS}
    require_code_owner_reviews = ${PUBLIC_BRANCH_CODE_OWNER_REVIEW}
    required_approving_review_count = ${PUBLIC_BRANCH_REVIEW_COUNT}

    dismissal_users       = ["${PROTECTED_BRANCH_REQUIRED_PULL_REQUEST_REVIEWS_USERS_LIST}"]
    dismissal_teams       = ["${PROTECTED_BRANCH_REQUIRED_PULL_REQUEST_REVIEWS_TEAMS_LIST}"]
  }

}

EOF
      terraform import "github_branch_protection_v3.${TERRAFORM_PUBLIC_REPO_NAME}_${j}" "${i}:${j}" 
    done
  done
done
}

import_public_repos
import_public_repo_branches