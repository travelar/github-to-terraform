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

# Public Repos
  # You can only list 100 items per page, so you can only clone 100 at a time.
  # This function uses the API to calculate how many pages of private repos you have.
get_private_pagination () {
    private_pages=$(curl -I -u $GITHUB_USER:$GITHUB_TOKEN "${API_URL_PREFIX}/orgs/${ORG}/repos?type=private&per_page=100" | grep -Eo '&page=\d+' | grep -Eo '[0-9]+' | tail -1;)
    echo "${private_pages:-1}"
}
  # This function uses the output from above and creates an array counting from 1->$ 
limit_private_pagination () {
  seq "$(get_private_pagination)"
}

  # Now lets import the repos, starting with page 1 and iterating through the pages
import_private_repos () {
  for PAGE in $(limit_private_pagination); do

    for i in $(curl -s -u $GITHUB_USER:$GITHUB_TOKEN "${API_URL_PREFIX}/orgs/${ORG}/repos?type=private&page=${PAGE}per_page=100" | jq -r 'sort_by(.name) | .[] | .name'); do
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
      PRIVATE_REPO_DELETE_MERGE=$(echo "$PRIVATE_REPO_PAYLOAD" | jq -r .delete_branch_on_merge)
      PRIVATE_REPO_AUTO_INIT=$(echo "$PRIVATE_REPO_PAYLOAD" | jq -r '.auto_init == true')
      PRIVATE_REPO_DEFAULT_BRANCH=$(echo "$PRIVATE_REPO_PAYLOAD" | jq -r .default_branch)
      PRIVATE_REPO_GITIGNORE_TEMPLATE=$(echo "$PRIVATE_REPO_PAYLOAD" | jq -r .gitignore_template)
      PRIVATE_REPO_LICENSE_TEMPLATE=$(echo "$PRIVATE_REPO_PAYLOAD" | jq -r '.license_template | select(type == "string")')
      PRIVATE_REPO_HOMEPAGE_URL=$(echo "$PRIVATE_REPO_PAYLOAD" | jq -r '.homepage | select(type == "string")')
     
      # Terraform doesn't like '.' in resource names, so if one exists then replace it with a dash
      TERRAFORM_PRIVATE_REPO_NAME=$(echo "${i}" | tr  "."  "_" | tr "-" "_" | tr '[:upper:]' '[:lower:]')

      cat >> ${ORG}-private-repos.tf << EOF
resource "github_repository" "${TERRAFORM_PRIVATE_REPO_NAME}" {
  name                    = "${i}"
  topics                  = ${PRIVATE_REPO_TOPICS}
  description             = "${PRIVATE_REPO_DESCRIPTION}"
  private                 = true
  has_wiki                = ${PRIVATE_REPO_WIKI}
  has_projects            = ${PRIVATE_REPO_PROJECTS}
  has_downloads           = ${PRIVATE_REPO_DOWNLOADS}
  has_issues              = ${PRIVATE_REPO_ISSUES}
  archived                = ${PRIVATE_REPO_ARCHIVED}
  allow_merge_commit      = ${PRIVATE_REPO_MERGE_COMMIT}
  allow_rebase_merge      = ${PRIVATE_REPO_REBASE_MERGE}
  allow_squash_merge      = ${PRIVATE_REPO_SQUASH_MERGE}
  delete_branch_on_merge  = ${PRIVATE_REPO_DELETE_MERGE}
  auto_init               = ${PRIVATE_REPO_AUTO_INIT}
  gitignore_template      = ${PRIVATE_REPO_GITIGNORE_TEMPLATE}
  license_template        = "${PRIVATE_REPO_LICENSE_TEMPLATE}"
  homepage_url            = "${PRIVATE_REPO_HOMEPAGE_URL}"
}

EOF
    
    #terraform import "github_repository.${TERRAFORM_PRIVATE_REPO_NAME}" "${i}"
    done
  done
}

import_private_repo_branches () {
  for PAGE in $(limit_private_pagination); do

    for i in $(curl -s -u $GITHUB_USER:$GITHUB_TOKEN "${API_URL_PREFIX}/orgs/${ORG}/repos?type=private&page=${PAGE}&per_page=100" | jq -r 'sort_by(.name) | .[] | .name'); do
    for j in $(curl -s -u $GITHUB_USER:$GITHUB_TOKEN "${API_URL_PREFIX}/repos/${ORG}/${i}/branches?protected=true&page=${PAGE}&per_page=100" | jq -r 'sort_by(.name) | .[] | .name'); do      
      PRIVATE_BRANCH_PAYLOAD=$(curl -s -u $GITHUB_USER:$GITHUB_TOKEN "${API_URL_PREFIX}/repos/${ORG}/${i}/branches/${j}?page=${PAGE}&per_page=100" -H "Accept: application/vnd.github+json")
      PRIVATE_BRANCH_PROTECTIONS=$(curl -s -u $GITHUB_USER:$GITHUB_TOKEN "${API_URL_PREFIX}/repos/${ORG}/${i}/branches/${j}/protection" -H "Accept: application/vnd.github+json")
      
      PRIVATE_REPO_PAYLOAD=$(curl -s -u $GITHUB_USER:$GITHUB_TOKEN "${API_URL_PREFIX}/repos/${ORG}/${i}" -H "Accept: application/vnd.github.mercy-preview+json")

      PROTECTED_BRANCH_ENFORCE_ADMINS=$(echo "$PRIVATE_REPO_PAYLOAD" | jq -r .enforce_admins.enabled) 

      # required_pull_request_review
      PRIVATE_BRANCH_DISMISS_STALE_REVIEWS=$(curl -s -u $GITHUB_USER:$GITHUB_TOKEN "${API_URL_PREFIX}/repos/${ORG}/${i}/branches/${j}/protection/required_pull_request_reviews" | jq -r .dismiss_stale_reviews)
      PRIVATE_BRANCH_REVIEW_COUNT=$(curl -s -u $GITHUB_USER:$GITHUB_TOKEN "${API_URL_PREFIX}/repos/${ORG}/${i}/branches/${j}/protection/required_pull_request_reviews" | jq -r .required_approving_review_count)
      PRIVATE_BRANCH_CODE_OWNER_REVIEW=$(curl -s -u $GITHUB_USER:$GITHUB_TOKEN "${API_URL_PREFIX}/repos/${ORG}/${i}/branches/${j}/protection/required_pull_request_reviews" | jq -r .require_code_owner_reviews)

      PROTECTED_BRANCH_REQUIRED_PULL_REQUEST_REVIEWS_USERS=$(echo "$PRIVATE_REPO_PAYLOAD" | jq -r '.required_pull_request_reviews.users[]?.login')
      PROTECTED_BRANCH_REQUIRED_PULL_REQUEST_REVIEWS_TEAMS=$(echo "$PRIVATE_REPO_PAYLOAD" | jq -r '.required_pull_request_reviews.team[]?.slug')
      PROTECTED_BRANCH_RESTRICTIONS_USERS=$(echo "$PRIVATE_REPO_PAYLOAD" | jq -r '.restrictions.users[]?.login')
      PROTECTED_BRANCH_RESTRICTIONS_TEAMS=$(echo "$PRIVATE_REPO_PAYLOAD" | jq -r '.restrictions.teams[]?.slug') 

      # convert bash arrays into csv list
      PROTECTED_BRANCH_RESTRICTIONS_USERS_LIST=$(echo "${PROTECTED_BRANCH_RESTRICTIONS_USERS}" | tr  " "  ", ")
      PROTECTED_BRANCH_RESTRICTIONS_TEAMS_LIST=$(echo "${PROTECTED_BRANCH_RESTRICTIONS_TEAMS}" | tr  " "  ", ")
      PROTECTED_BRANCH_REQUIRED_PULL_REQUEST_REVIEWS_USERS_LIST=$(echo "${PROTECTED_BRANCH_REQUIRED_PULL_REQUEST_REVIEWS_USERS}" | tr  " "  ", ")
      PROTECTED_BRANCH_REQUIRED_PULL_REQUEST_REVIEWS_TEAMS_LIST=$(echo "${PROTECTED_BRANCH_REQUIRED_PULL_REQUEST_REVIEWS_TEAMS}" | tr  " "  ", ")

      # required_status_checks
      PRIVATE_BRANCH_STRICT=$(curl -s -u $GITHUB_USER:$GITHUB_TOKEN "${API_URL_PREFIX}/repos/${ORG}/${i}/branches/${j}/protection/required_status_checks" | jq -r .strict)
      PRIVATE_BRANCH_CONTEXTS=$(curl -s -u $GITHUB_USER:$GITHUB_TOKEN "${API_URL_PREFIX}/repos/${ORG}/${i}/branches/${j}/protection/required_status_checks" | jq -r .contexts)
     
      # Terraform doesn't like '.' in resource names, so if one exists then replace it with a dash
      TERRAFORM_PRIVATE_REPO_NAME=$(echo "${i}" | tr  "."  "_" | tr "-" "_" | tr '[:upper:]' '[:lower:]')

      cat >> ${ORG}-private-repos.tf << EOF
resource "github_branch_protection_v3" "${TERRAFORM_PRIVATE_REPO_NAME}_${j}" {
  repository         = "${i}"
  branch             = "${j}"
  enforce_admins = ${PROTECTED_BRANCH_ENFORCE_ADMINS}

  required_status_checks {
    strict = ${PRIVATE_BRANCH_STRICT}
    contexts = ${PRIVATE_BRANCH_CONTEXTS}
  }

  required_pull_request_reviews {
    dismiss_stale_reviews = ${PRIVATE_BRANCH_DISMISS_STALE_REVIEWS}
    require_code_owner_reviews = ${PRIVATE_BRANCH_CODE_OWNER_REVIEW}
    required_approving_review_count = ${PRIVATE_BRANCH_REVIEW_COUNT}

    dismissal_users       = ["${PROTECTED_BRANCH_REQUIRED_PULL_REQUEST_REVIEWS_USERS_LIST}"]
    dismissal_teams       = ["${PROTECTED_BRANCH_REQUIRED_PULL_REQUEST_REVIEWS_TEAMS_LIST}"]
  }

}

EOF
      terraform import "github_branch_protection_v3.${TERRAFORM_PRIVATE_REPO_NAME}_${j}" "${i}:${j}" 
    done
  done
done
}

import_private_repos
import_private_repo_branches