Gem::Specification.new do |s|

  s.name            = 'logstash-output-hdfs'
  s.version         = '0.1.0'
  s.licenses        = ['Apache License (2.0)']
  s.summary         = "This output will write events to files in hdfs"
  s.description     = "This gem is a logstash plugin required to be installed on top of the Logstash core pipeline using $LS_HOME/bin/plugin install gemname. This gem is not a stand-alone program"
  s.authors         = ["Pere Urbon-Bayes"]
  s.email           = 'pere.urbon@gmail.com'
  s.homepage        = "http://www.purbon.com"
  s.require_paths = ["lib"]

  # Files
  s.files         = Dir.glob(["logstash-output-hadoop.gemspec", "lib/**/*.rb", "spec/**/*.rb", "vendor/*"])

  # Tests
  s.test_files = s.files.grep(%r{^(test|spec|features)/})

  # Special flag to let us know this is actually a logstash plugin
  s.metadata = { "logstash_plugin" => "true", "logstash_group" => "output" }

  # Gem dependencies
  s.add_runtime_dependency "logstash-core-plugin-api", "~> 2.0"
  s.add_runtime_dependency 'logstash-input-generator'

  s.requirements << "jar org.apache.hadoop, hadoop-client, 2.7.2"

  s.add_development_dependency "bundler", "~> 1.9"
  s.add_development_dependency "rake", "~> 10.0"
  s.add_development_dependency 'jar-dependencies', '~> 0.3.4'
  s.add_development_dependency 'logstash-devutils'
end

