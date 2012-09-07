require "bundler"
Bundler.setup

gemspec = eval(File.read("houston.gemspec"))

task :build => "#{gemspec.full_name}.gem"

file "#{gemspec.full_name}.gem" => gemspec.files + ["houston.gemspec"] do
  system "gem build houston.gemspec"
  system "gem install houston-#{Houston::VERSION}.gem"
end
