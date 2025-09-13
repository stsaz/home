#!/bin/bash
# Multi-repo git commands

set -e

if test "$#" -lt 2 ; then
	echo "Usage: gitall.sh X_COMMAND|GIT_COMMAND REPO..."
	echo "X_COMMAND: xrebase xdate xpush xlog xgitk"
	exit 1
fi

CMD=$1
shift
REPOS=$@

run_cmd() {
	if test "$CMD" == "xrebase" ; then
		BRANCH=$(git branch --show-current)
		git rebase -i origin/$BRANCH

	elif test "$CMD" == "xdate" ; then
		BRANCH=$(git branch --show-current)
		git rebase --reset-author-date origin/$BRANCH

	elif test "$CMD" == "xpush" ; then
		BRANCH=$(git branch --show-current)
		git push origin $BRANCH

	elif test "$CMD" == "xlog" ; then
		BRANCH=$(git branch --show-current)
		git log --oneline origin/$BRANCH..HEAD

	elif test "$CMD" == "xgitk" ; then
		gitk --all

	else
		git $CMD
	fi
}

for repo in $REPOS ; do
	if test -d $repo/.git ; then
		echo '#' $repo
		cd $repo
		run_cmd
		cd - >/dev/null
	fi
done
