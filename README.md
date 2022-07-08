This is a simple bash script to simply import a Github Organization into Terraform. It uses the Github API and Terraform CLI to import the following resources:
- all public repos (includes pagination support for Orgs with 100+ repos)
- all private repos (includes pagination support for Orgs with 100+ repos)
- all team repos (includes pagination support for Orgs with 100+ repos)
- all teams
- all team memberships
- all organization members

After importing the resources the script _also_ writes a basic terraform.tf config for **each resource**, making this a fully automated process.

## How the script works
### Public repos
Imports all public repos owned by the organization (includes full pagination support for Orgs with 100+ repos). Also writes a Terraform resource block in a single file (`$ORG-public-repos.tf`), using the following template and populating it with values pulled via the Github API:

```
resource "github_repository" "$PUBLIC_REPO_NAME" {
  name        = "$PUBLIC_REPO_NAME"
  private     = false
  description = "$PUBLIC_REPO_DESCRIPTION"
  has_wiki    = "$PUBLIC_REPO_WIKI"
  has_downloads = "$PUBLIC_REPO_DOWNLOADS"
  has_issues  = "$PUBLIC_REPO_ISSUES"
}
```

### Private repos
Imports all private repos owned by the organization (includes full pagination support for Orgs with 100+ repos). Also writes a Terraform resource block in a single file (`$ORG-private-repos.tf`), using the following template and populating it with values pulled via the Github API:

```
resource "github_repository" "$PRIVATE_REPO_NAME" {
  name        = "$PRIVATE_REPO_NAME"
  private     = true
  description = "$PRIVATE_REPO_DESCRIPTION"
  has_wiki    = "$PRIVATE_REPO_WIKI"
  has_downloads = "$PRIVATE_REPO_DOWNLOADS"
  has_issues  = "$PRIVATE_REPO_ISSUES"
}
```

### Team repos
Imports all team repos owned by the organization (includes full pagination support for Orgs with 100+ repos). Also writes a Terraform resource block in a unique file per team (`$ORG-teams-$TEAM_NAME.tf`), using the following template and populating it with values pulled via the Github API:

```
resource "github_team_repository" "$TEAM_NAME-$TERRAFORM_TEAM_REPO_NAME" {
  team_id    = "$TEAM_ID"
  repository = "$REPO_NAME"
  permission = "admin" or "push" or "pull"
}
```

### Teams
Imports all teams belonging to the organization. Also writes a Terraform resource block in a unique file per team (`$ORG-teams-$TEAM_NAME.tf`), using the following template and populating it with values pulled via the Github API:

```
resource "github_team" "$TEAM_NAME" {
  name        = "$TEAM_NAME"
  description = "$TEAM_DESCRIPTION"
  privacy     = "closed" or "secret"
}
```

### Team memberships
Imports the team membership for all teams owned by the organization (what users belong to what teams). Also writes a Terraform resource block in a unique file per team (`$ORG-team-memberships-$TEAM_NAME.tf`), using the following template and populating it with values pulled via the Github API:

```
resource "github_team_membership" "$TEAM_NAME-$USER_NAME" {
  username    = "$USER_NAME"
  team_id     = "$TEAM_ID"
  role        = "maintainer" or "member"
}
```

### Organization members
Imports all users belonging to the organization. Also writes a Terraform resource block in a single file (`$ORG-users.tf`), using the following template and populating it with values pulled via the Github API:

```
resource "github_membership" "$USER_NAME" {
  username        = "$USER_NAME"
  role            = "member"
}
```

## How to use the script
### Requirements
- An existing Github account with a user that belongs to an organization
- A github [personal access token](https://help.github.com/articles/creating-a-personal-access-token-for-the-command-line/) with the following permissions:
  - repo (all)
  - admin:org (all)
- Terraform
- jq

### Do it
- `git clone` this repo
- create a basic terraform configuration file, e.g. `main.tf` with
  something like:

  ```hcl
  provider "github" {
    token        = "TOKENGOESHERE"
    organization = "my_org"
    # optional, if using GitHub Enterprise
    base_url     =  "https://github.mycompany.com/api/v3/"
  }
  ```
- run `terraform init` to e.g. install the GitHub provider
- configure the variables at the top of the script
  - `GITHUB_TOKEN=...`
  - `ORG=...`
  - if you're using GitHub Enterprise, `API_URL_PREFIX=...`
  or remember to pass them in via the environment
- run the scriptm, perhaps passing the necessary environment variables
  ```
  GITHUB_TOKEN=12334...4555 ORG=my_org github-to-terraform.sh
  ```
- run a terraform plan to see that everything was imported and that no changes are required.
  - some manual modifications _could_ be required since not every field supported by Terraform has been implemented by this script.
  - HEADS UP - the script hardcodes user roles to "member".

### Using with GitHub Enterprise

This should also work with GitHub Enterprise deployments if you also
set (either editing the script or via an environment variable) the
`API_URL_PREFIX` correctly,
e.g. `https://github.mycompany.com/api/v3`.

