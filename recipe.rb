HOST = node[:hostname]
USER = 'isucon'

ISU01 = 'ip-192-168-0-11'
ISU02 = 'ip-192-168-0-12'
ISU03 = 'ip-192-168-0-13'

MItamae::ResourceContext.class_eval do
	def enable_if(b)
		if b
			%i[enable start]
		else
			%i[disable stop]
		end
	end
end

if HOST == ISU01
  service 'isuride-go.service' do
	  action %i[enable start]
  end
  service 'isuride-matcher.service' do
	  action %i[enable start]
  end
  service 'isuride-payment_mock.service' do
	  action %i[enable start]
  end
else
  service 'isuride-go.service' do
	  action %i[disable stop]
  end
  service 'isuride-matcher.service' do
	  action %i[disable stop]
  end
  service 'isuride-payment_mock.service' do
	  action %i[disable stop]
  end
end

if HOST == ISU02
  service 'mysql.service' do
	  action %i[enable start]
  end
else
  service 'mysql.service' do
	  action %i[disable stop]
  end
end

if HOST == ISU01
  service 'nginx.service' do
	  action %i[enable start]
  end
else
  service 'nginx.service' do
	  action %i[disable stop]
  end
end

#package 'redis'
#service 'redis' do
#	action %i[enable start]
#end

{
	'nginx' => '/etc/nginx/nginx.conf',
	'mysql' => '/etc/mysql/mysql.conf.d/mysqld.cnf',
	'isuride-go.service' => '/etc/systemd/system/isuride-go.service',
}.each do |service, conf|
	conf_source = "./#{HOST}/#{File.basename conf}"
	next unless File.file? conf_source

	remote_file conf do
		source conf_source
		mode '0644'
	end
end

###
# Monitoring tools
###

execute 'install netdata' do
	command 'bash -c "bash <(curl -SLs https://my-netdata.io/kickstart.sh) all --non-interactive --stable-channel --no-updates --disable-telemetry"'
	not_if "systemctl list-unit-files | grep '^netdata.service'"
end

#service 'netdata' do
#	action %i[disable stop]
#end

package 'percona-toolkit'
