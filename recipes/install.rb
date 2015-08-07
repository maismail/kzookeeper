#
# DO NOT EDIT THIS FILE DIRECTLY - UNLESS YOU KNOW WHAT YOU ARE DOING
#

user node[:kzookeeper][:user] do
  action :create
  supports :manage_home => true
  home "/home/#{node[:kzookeeper][:user]}"
  shell "/bin/bash"
  not_if "getent passwd #{node[:kzookeeper]['user']}"
end

group node[:kzookeeper][:group] do
  action :modify
  members ["#{node[:kzookeeper][:user]}"]
  append true
end


# See ark resource here: https://github.com/burtlo/ark
# It will: fetch it to to /var/cache/chef/
# unpack it to the default path (/usr/local/XXX-1.2.3)
# create a symlink for :home_dir (/usr/local/XXX) 
# add /user/local/XXX/bin to the enviroment PATH variable
#  ark 'kzookeeper' do
#    url node[:kzookeeper][:url]
#    version node[:kzookeeper][:version]
#    path node[:kzookeeper][:version_dir]
#    home_dir node[:kzookeeper][:home_dir]
#    
#    append_env_path true
#    owner node[:kzookeeper][:user]
#  end

# bash "experiment_install_bash" do
#     user "root"
#     code <<-EOF
# Do something here...
# touch #{node[:kzookeeper][:version_dir]}/.installed
# EOF
#   not_if { ::File.exists?( "#{node[:kzookeeper][:version_dir]}/.installed" ) }
# end


# Pre-Experiment Code

require 'json'

include_recipe 'build-essential::default'
include_recipe 'java::default'

zookeeper node[:zookeeper][:version] do
  user        node[:kzookeeper][:user]
  mirror      node[:zookeeper][:mirror]
  checksum    node[:zookeeper][:checksum]
  install_dir node[:zookeeper][:install_dir]
  data_dir    node[:zookeeper][:config][:dataDir]
  action      :install
end

zk_ip = private_recipe_ip("kzookeeper", "default")

include_recipe "zookeeper::config_render"

template "#{node[:zookeeper][:base_dir]}/bin/zookeeper-start.sh" do
  source "zookeeper-start.sh.erb"
  owner node[:kzookeeper][:user]
  group node[:kzookeeper][:user]
  mode 0770
  variables({ :zk_ip => zk_ip })
end

template "#{node[:zookeeper][:base_dir]}/bin/zookeeper-stop.sh" do
  source "zookeeper-stop.sh.erb"
  owner node[:kzookeeper][:user]
  group node[:kzookeeper][:user]
  mode 0770
end

directory "#{node[:zookeeper][:base_dir]}/data" do
  owner node[:kzookeeper][:user]
  group node[:kzookeeper][:group]
  mode "755"
  action :create
  recursive true
end

config_hash = {
  clientPort: 2181, 
  dataDir: "#{node[:zookeeper][:base_dir]}/data", 
  tickTime: 2000,
  syncLimit: 3,
  initLimit: 60,
  autopurge: {
    snapRetainCount: 1,
    purgeInterval: 1
  }
}


node[:kzookeeper][:default][:private_ips].each_with_index do |ipaddress, index|
config_hash["server#{index}"]="#{ipaddress}:2888:3888"
end

zookeeper_config "/opt/zookeeper/zookeeper-#{node[:zookeeper][:version]}/conf/zoo.cfg" do
  config config_hash
  user   node[:kzookeeper][:user]
  action :render
end

template '/etc/default/zookeeper' do
  source 'environment-defaults.erb'
  owner node[:kzookeeper][:user]
  group node[:kzookeeper][:group]
  action :create
  mode '0644'
  cookbook 'zookeeper'
  notifies :restart, 'service[zookeeper]', :delayed
end

template '/etc/init.d/zookeeper' do
  source 'zookeeper.initd.erb'
  owner 'root'
  group 'root'
  action :create
  mode '0755'
  notifies :restart, 'service[zookeeper]', :delayed
end

service 'zookeeper' do
  supports :status => true, :restart => true, :reload => true
  action :enable
end


# Configuration Files
