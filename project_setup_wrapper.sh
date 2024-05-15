#!/bin/bash

# This is a wrapper script to setup your personal project repo.
# You can download this single script and run. No need to clone the whole repo
#
# Input:
#   -d: your project directory, including your repo name

while getopts "d:" opt; do
    case $opt in
    d)
        repo_dir="$OPTARG"
        ;;
    \?)
        echo "Usage: cmd [-d] [-n](optional)"
        ;;
    esac
done

repo_name=$(basename ${repo_dir})
cd ${repo_dir}

is_repo=$(git rev-parse --is-inside-work-tree 2>/dev/null)

if [ "$is_repo" != "true" ]; then
    echo "The folder ${repo_dir} is not a Git repository. "
    git clone git@github.com:ThomasYeoLab/${repo_name}.git ${repo_dir}
    exit_status=$?
    if [ ! $exit_status -eq 0 ]; then
        echo "Cannot find your repo ThomasYeoLab/${repo_name}, please contact github admin."
        exit 1
    fi
fi

echo "Creating directory... "
if [ ! -d "${repo_dir}/setup/hooks" ]; then
    mkdir -p ${repo_dir}/setup/hooks
fi
if [ ! -d "${repo_dir}/unit_tests" ]; then
    mkdir -p ${repo_dir}/unit_tests
fi
if [ ! -d "${repo_dir}/examples" ]; then
    mkdir -p ${repo_dir}/examples
fi

echo "Setup pre-push hook..."
wget https://raw.githubusercontent.com/ThomasYeoLab/project_setup/main/hooks/pre-push -O ${repo_dir}/setup/hooks/pre-push
chmod 755 ${repo_dir}/setup/hooks/pre-push
ln -s ${repo_dir}/setup/hooks/pre-push ${repo_dir}/.git/hooks/pre-push

echo "Setup pre-commit hook..."
wget https://raw.githubusercontent.com/ThomasYeoLab/project_setup/main/hooks/pre-commit -O ${repo_dir}/setup/hooks/pre-commit
chmod 755 ${repo_dir}/setup/hooks/pre-commit
ln -s ${repo_dir}/setup/hooks/pre-commit ${repo_dir}/.git/hooks/pre-commit

echo "Update necessary files..."
wget https://raw.githubusercontent.com/ThomasYeoLab/project_setup/main/update_setup -O ${repo_dir}/setup/update_setup
chmod 755 ${repo_dir}/setup/update_setup

git add .
git commit -m "Initial setup of ${repo_name}"

sh ${repo_dir}/setup/update_setup

echo "ThomasYeoLab/${repo_name} setup finished!"
