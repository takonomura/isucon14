#!/bin/bash
set -e

HELPER_TOKEN='Xl/Jp2uZ/DNQsohc2AHCiGD3h5sJqQaHZS6tjEPRTsU='
HELPER_BASE_URL='https://isucon-helper-sgaqp4bzxq-an.a.run.app'

REPO="takonomura/$(git remote get-url origin | sed -E 's#^.*/([^/]+)\.git$#\1#g')"
REVISION="$(git rev-parse HEAD)"

echo_comment() {
	echo "Score: $@"
	echo '```'
	cat
	echo '```'
}

comment_commit() {
	curl -sS -H "Authorization: Bearer $HELPER_TOKEN" -H 'Content-Type: text/plain' --data-binary @- "$HELPER_BASE_URL/$REPO/commits/$REVISION/comments"
}

comment_issue() {
	(echo "Revision: $REVISION"; cat) | curl -sS -H "Authorization: Bearer $HELPER_TOKEN" -H 'Content-Type: text/plain' --data-binary @- "$HELPER_BASE_URL/$REPO/issues/1/comments"
}

echo "Sending comment for $REVISION ($REPO)"
echo_comment "$@" | tee >(comment_commit) >(comment_issue)
