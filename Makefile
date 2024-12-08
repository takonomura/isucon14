.PHONY: deploy mitamae build rotate-logs restart-app restart-nginx restart-mysql alp slowquery report-logs mitamae-dry-run sql-stats

deploy: mitamae build rotate-logs restart-app restart-nginx restart-mysql
	curl --data-urlencode 'payload={"username":"$(shell hostname)","icon_emoji":"rocket","text":"Deployed $(shell git rev-parse --abbrev-ref HEAD) (<https://github.com/takonomura/isucon14/tree/$(shell git rev-parse HEAD)|$(shell git rev-parse --short HEAD)>)"}' https://hooks.slack.com/services/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

mitamae:
	sudo mitamae local recipe.rb

build:
	@make -C webapp/go build

rotate-logs:
	@scripts/rotate-logs.sh

restart-app:
	@scripts/restart.sh isuride-go.service

restart-nginx:
	@scripts/restart.sh nginx.service

restart-mysql:
	@scripts/restart.sh mysql.service

alp:
	alp json --config alp.yml

sql-stats:
	@scripts/sql-performance.sh

slowquery:
	sudo pt-query-digest /var/log/mysql/mysql-slow.log

report-logs:
	@scripts/report-logs.sh

mitamae-dry-run:
	sudo mitamae local recipe.rb --dry-run
