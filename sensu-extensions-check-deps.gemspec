# coding: utf-8

Gem::Specification.new do |spec|
  spec.name          = "sensu-extensions-check-deps"
  spec.version       = "0.0.1"
  spec.authors       = ["Vladimir Mevzos"]
  spec.email         = ["<vladimir@appsflyer.com>"]

  spec.summary       = "check deps sensu filter with extra features"
  spec.description   = "check deps sensu filter with extra features"
  spec.homepage      = "https://github.com/mau1024/sensu-extensions-check-deps"

  spec.files         = Dir.glob('{bin,lib}/**/*') + %w(LICENSE README.md CHANGELOG.md)
  spec.require_paths = ["lib"]

  spec.add_dependency "sensu-extension"

  spec.add_development_dependency "bundler", "~> 1.6"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "rspec"
  spec.add_development_dependency "sensu-logger"
  spec.add_development_dependency "sensu-settings"
end
