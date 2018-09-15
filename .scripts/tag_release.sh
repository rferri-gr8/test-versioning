#!/bin/bash

# exit w/ 0 when any command returns 0
set -e

remote=origin
release_branch_prefix=release
status_check=1
version=""
while getopts "v:r:di" opt; do
  case $opt in
    v)
      version="$OPTARG"
      ;;
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
if [ "$version" = "" ]; then
	options_are_valid=0
	>&2 echo "Missing version number (-v)"
fi

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

release_branch_name="$release_branch_prefix/$version"

# fetch latest from remote
git fetch $remote

# checkout the latest on trunk
git checkout $remote/$release_branch_name

release_branch_current_version=$(cat package.json \
  | grep version \
  | head -1 \
  | awk -F: '{ print $2 }' \
  | sed 's/[",]//g' \
  | tr -d '[[:space:]]')

echo "Current release branch version: $release_branch_current_version"

tag_version=$(echo $release_branch_current_version | sed 's/-.*//')
tag_version="v$tag_version"
echo "Release tag version: $tag_version"

# bump to the release tag version
npm --no-git-tag-version version ${tag_version#v}

# commit the version bump
git add package.json
git add npm-shrinkwrap.json
git commit -m "Bump version number to $tag_version"
git push $remote HEAD:refs/heads/$release_branch_name

git tag $tag_version $remote/$release_branch_name > /dev/null

echo "Pushing tag $tag_version to $remote"
git push $remote $tag_version

# have npm bump the minor version number w/out creating a git tag
release_branch_new_version=$(npm --no-git-tag-version version prepatch)
# hack: old version of npm version doesn't allow --preid=snapshot arg?
release_branch_new_version=${release_branch_new_version::-2}
release_branch_new_version="$release_branch_new_version-rc"

echo "New release branch version: $release_branch_new_version"
npm --no-git-tag-version version ${release_branch_new_version#v}

# commit the version bump
git add package.json
git add npm-shrinkwrap.json
git commit -m "Bump version number to $release_branch_new_version"
git push $remote HEAD:refs/heads/$release_branch_name

