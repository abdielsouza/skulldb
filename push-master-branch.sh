#!/bin/bash
# Script to push the master branch to the remote repository
# Run this script after the PR is merged to complete the branch creation

set -e

echo "Pushing master branch to remote repository..."
git push origin master

echo "Verifying master branch was pushed successfully..."
git ls-remote --heads origin master

echo "✅ Master branch successfully pushed to remote!"
echo "The master branch now contains all changes from the development branch."
