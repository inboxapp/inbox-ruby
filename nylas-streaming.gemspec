# encoding: utf-8
require "./lib/nylas/version.rb"

Gem::Specification.new do |gem|
  gem.name = "nylas-streaming"
  gem.homepage = "http://github.com/nylas/nylas-ruby"
  gem.license = "MIT"
  gem.summary = %Q{Gem for interacting with the Nylas API}
  gem.description = %Q{Gem for interacting with the Nylas API.}
  gem.version = Nylas::VERSION
  gem.email = "support@nylas.com"
  gem.authors = ["Nylas, Inc."]
  gem.files = Dir.glob("lib/{nylas-streaming.rb,nylas-streaming/**/*.rb}")
  gem.platform = "ruby"

  gem.metadata = {
    "bug_tracker_uri"   => "https://github.com/nylas/nylas-ruby/issues",
    "changelog_uri"     => "https://github.com/nylas/nylas-ruby/blob/master/CHANGELOG.md",
    "documentation_uri" => "http://www.rubydoc.info/gems/nylas",
    "homepage_uri"      => "https://www.nylas.com",
    "source_code_uri"   => "https://github.com/nylas/nylas-ruby",
    "wiki_uri"          => "https://github.com/nylas/nylas-ruby/wiki"
  }

  gem.add_runtime_dependency "nylas", ">= 4.0"
  gem.add_runtime_dependency "yajl-ruby", "~> 1.2", ">= 1.2.1"
  gem.add_runtime_dependency "em-http-request", "~> 1.1", ">= 1.1.3"

  gem.add_development_dependency "yard", ">= 0.9.12"
  gem.add_development_dependency "bundler", ">= 1.3.5"
  gem.add_development_dependency "jeweler", ">= 2.1.2"

  gem.add_development_dependency "pry", ">= 0.10.4"
  gem.add_development_dependency "pry-nav", ">= 0.2.4"
  gem.add_development_dependency "pry-stack_explorer", ">= 0.4.9.2"

  gem.add_development_dependency "rspec", ">= 3.5.0"
  gem.add_development_dependency "shoulda", ">= 3.4.0"
  gem.add_development_dependency "webmock", ">= 2.1.0", ">= 2.1.0"

  gem.add_development_dependency "sinatra", ">= 1.4.7"

  gem.add_development_dependency "informed", "~> 1.0"
  gem.add_development_dependency "faker", "~> 1.8"
  gem.add_development_dependency "awesome_print", "~> 1.0"
  gem.add_development_dependency "simplecov", "~> 0.15"
  gem.add_development_dependency "rubocop", "~> 0.51"
  gem.add_development_dependency "rubocop-rspec", "~> 1.20"
end
