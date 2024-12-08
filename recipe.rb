HOST = node[:hostname]
USER = 'isucon'

MItamae::ResourceContext.class_eval do
	def enable_if(b)
		if b
			%i[enable start]
		else
			%i[disable stop]
		end
	end
end

service 'isucon.go.service' do
	action %i[enable start]
end

service 'mysql' do
	action %i[enable start]
end

service 'nginx' do
	action %i[enable start]
end

#package 'redis'
#service 'redis' do
#	action %i[enable start]
#end

{
	'nginx' => '/etc/nginx/nginx.conf',
	'mysql' => '/etc/mysql/mysql.conf.d/mysqld.cnf',
	'isucon.go.service' => '/etc/systemd/system/isucon.go.service',
}.each do |service, conf|
	conf_source = "./#{HOST}/#{File.basename conf}"
	next unless File.file? conf_source

	remote_file conf do
		source conf_source
		mode '0644'
		notifies :restart, "service[#{service}]"
	end
end

###
# Monitoring tools
###

execute 'install netdata' do
	command 'bash -c "bash <(curl -Ss https://my-netdata.io/kickstart.sh) all --non-interactive --stable-channel --no-updates --disable-telemetry"'
	not_if "systemctl list-unit-files | grep '^netdata.service'"
end

#service 'netdata' do
#	action %i[disable stop]
#end

package 'percona-toolkit'
