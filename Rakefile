require 'rake/testtask'
require "bundler"
Bundler.setup

gemspec = eval(File.read("houston.gemspec"))

task :build => "#{gemspec.full_name}.gem"

file "#{gemspec.full_name}.gem" => gemspec.files + ["houston.gemspec"] do
  system "gem build houston.gemspec"
end

Rake::TestTask.new do |t|
  t.pattern = 'test/**/*_test.rb'
end

task :default => :test