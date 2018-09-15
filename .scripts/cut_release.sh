#!/bin/bash

# exit w/ 0 when any command returns 0
set -e

remote=origin
trunk_branch_name=master
status_check=1
while getopts "v:r:di" opt; do
  case $opt in
    r)
      remote="$OPTARG"
      ;;
    i)
      status_check=0
      ;;
    \?)
      >&2 echo "Invalid option: -$OPTARG"
      exit 1
      ;;
    :)
      >&2 echo "Option -$OPTARG requires an argument."
      exit 1
      ;;
  esac
done

options_are_valid=1
if [ "$remote" = "" ]; then
	options_are_valid=0
	>&2 echo "Missing remote name (-r)"
fi

if [ $options_are_valid -eq 0 ]; then
	>&2 echo "Please try command again with the correct option(s)"
	exit 1
fi

if [ $status_check -gt 0 ]; then
	git_status=$(git status --porcelain)
	if [ -n "$git_status" ]; then
		>&2 echo "Please clean your working directory and try command again."
		>&2 echo "To skip this check, pass the -i option."
		>&2 echo ""
		>&2 echo "The following files have been changed or added to your working directory:"
		>&2 echo "$git_status"
		exit 1
	fi
fi

# fetch latest from remote
git fetch $remote

# checkout the latest on trunk
git checkout $remote/$trunk_branch_name

trunk_current_version=$(cat package.json \
  | grep version \
  | head -1 \
  | awk -F: '{ print $2 }' \
  | sed 's/[",]//g' \
  | tr -d '[[:space:]]')

echo "Current trunk version: $trunk_current_version"

# have npm bump the minor version number w/out creating a git tag
trunk_new_version=$(npm --no-git-tag-version version preminor)
# hack: old version of npm version doesn't allow --preid=snapshot arg?
trunk_new_version=${trunk_new_version::-2}
trunk_new_version="$trunk_new_version-snapshot"
echo "New trunk version: $trunk_new_version"

npm --no-git-tag-version version ${trunk_new_version#v}

# commit the version bump
git add package.json
git add npm-shrinkwrap.json
git commit -m "Bump version number to $trunk_new_version"
git push $remote HEAD:$trunk_branch_name

# get release branch version from current trunk version
release_branch_version=$(echo $trunk_current_version | sed 's/-.*//')
release_branch_version=${release_branch_version::-2}

release_branch_name="release/${release_branch_version#v}"
echo "Opening release branch $release_branch_name"

# rewind one commit + cut release
git reset --hard HEAD~1

# set -rc version
release_candidate_version="$release_branch_version.0-rc"
npm --no-git-tag-version version ${release_candidate_version#v}

# commit the version bump
git add package.json
git add npm-shrinkwrap.json
git commit -m "Bump version number to $release_candidate_version"

# create the branch
git push -u $remote HEAD:$release_branch_name
