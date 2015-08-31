# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'crawler/version'

Gem::Specification.new do |spec|
  spec.name          = "crawler"
	spec.version       = Crawler.version
  spec.authors       = ["carney lee"]
	spec.email         = ["carney520@hotmail.com"]

  spec.summary       = %q{A simple web crawler write by Ruby,base on Redis}
  spec.description   = %q{A simple web crawler write by Ruby,base on Redis}
	spec.requirements  << %q{You must have	Redis installed}
	spec.homepage      = "https://github.com/carney520/crawler"
  spec.license       = "MIT"

  # Prevent pushing this gem to RubyGems.org by setting 'allowed_push_host', or
  # delete this section to allow pushing this gem to any host.
  if spec.respond_to?(:metadata)
    spec.metadata['allowed_push_host'] = "TODO: Set to 'http://mygemserver.com'"
  else
    raise "RubyGems 2.0 or newer is required to protect against public gem pushes."
  end

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.10"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec"
	spec.add_development_dependency "mechanize"
	spec.add_development_dependency "redis"
end
