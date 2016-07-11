require 'jars/installer'

@files=[]

task :default do
  system("rake -T")
end

require "logstash/devutils/rake"


desc "install jars"
task :install_jars do
  Jars::Installer.vendor_jars!
end
