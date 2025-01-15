# frozen_string_literal: true

require "./gem_config"

Gem::Specification.new do |gem|
  gem.name = "nylas"
  gem.summary = %(Gem for interacting with the Nylas API)
  gem.version = Nylas::VERSION
  gem.email = "support@nylas.com"
  gem.authors = ["Nylas, Inc."]
  gem.license = "MIT"

  # Runtime dependencies
  gem.add_runtime_dependency "base64"
  gem.add_runtime_dependency "mime-types", "~> 3.5", ">= 3.5.1"
  gem.add_runtime_dependency "ostruct", "~> 0.6"
  gem.add_runtime_dependency "rest-client", ">= 2.0.0", "< 3.0"
  gem.add_runtime_dependency "yajl-ruby", "~> 1.4.3", ">= 1.2.1"

  # Add remaining gem details and dev dependencies
  GemConfig.apply(gem)
end
