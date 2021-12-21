#!/bin/bash

REPOORG="ORGNAME"
REPO_NAMES=("REPONAME1" "REPONAME2")
CODEFREEZEBRANCH="code_freeze_dec_2021"
read -p "Enter your github username: " GITHUB_USER
read -p "Enter your github access token: " GITHUB_TOKEN

for repo in "${REPO_NAMES[@]}"
do
  echo "For repository: ${REPOORG}/${repo}" 
  read -p "Confirm if you want to trigger code freeze for the repo.." yn

  echo "cloning repository"
  `git clone git@github.com:${REPOORG}/${repo}`

  echo "Creating code freeze branch..."
  branch_create_command="git checkout -b ${CODEFREEZEBRANCH}"
  cd $repo && eval $branch_create_command && eval "git push origin ${CODEFREEZEBRANCH}"

  echo "Update default branch and allow merge commits to the repo..."
  repo_update_cmd="curl -X PATCH -u ${GITHUB_USER}:${GITHUB_TOKEN} -H \"Accept: application/vnd.github.v3+json\" https://api.github.com/repos/${REPOORG}/${repo} -d '{\"default_branch\":\"${CODEFREEZEBRANCH}\", \"allow_merge_commit\":\"true\"}'"
  echo $repo_update_cmd
  eval $repo_update_cmd

  echo "Setting branch protection rules for master branch..."
  branch_protection_cmd="curl -X POST -u ${GITHUB_USER}:${GITHUB_TOKEN} -H \"Accept: application/vnd.github.luke-cage-preview+json\" https://api.github.com/repos/${REPOORG}/${repo}/branches/master/protection/restrictions/teams -d '[\"codefreezeadmins\"]'"
  eval $branch_protection_cmd
done

