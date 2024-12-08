#!/bin/bash
set -e

HELPER_TOKEN='Xl/Jp2uZ/DNQsohc2AHCiGD3h5sJqQaHZS6tjEPRTsU='
HELPER_BASE_URL='https://isucon-helper-sgaqp4bzxq-an.a.run.app'

REPO="takonomura/$(git remote get-url origin | sed -E 's#^.*/([^/]+)\.git$#\1#g')"
REVISION="$(git rev-parse HEAD)"

echo_comment() {
	echo "Hostname: $(hostname)"
	if [ -f /var/log/nginx/access.log ]; then
		echo
		echo '##### Nginx Access Log'
		echo
		echo '<details>'
		echo
		echo '```'
		echo "$(make alp -s)"
		echo '```'
		echo
		echo '</details>'
	fi
	if sudo systemctl is-active "mysql.service" >/dev/null; then
		echo
		echo '##### MySQL Performance Stats'
		echo
		echo '<details>'
		echo
		echo '```'
		echo "$(make sql-stats -s)"
		echo '```'
		echo
		echo '</details>'
	fi
	if sudo test -f /var/log/mysql/mysql-slow.log; then
		echo
		echo '##### MySQL Slow Queries Log'
		echo
		echo '<details>'
		echo
		echo '```'
		echo "$(make slowquery -s)"
		echo '```'
		echo
		echo '</details>'
	fi
}

echo "Sending comment for $REVISION ($REPO)"
echo_comment | curl -sS -H "Authorization: Bearer $HELPER_TOKEN" -H 'Content-Type: text/plain' --data-binary @- "$HELPER_BASE_URL/$REPO/commits/$REVISION/comments"
