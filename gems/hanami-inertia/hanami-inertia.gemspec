# frozen_string_literal: true

require_relative "lib/hanami/inertia/version"

Gem::Specification.new do |spec|
  spec.name          = "hanami-inertia"
  spec.version       = Hanami::Inertia::VERSION
  spec.authors       = ["Vitaliy"]
  spec.email         = ["vitaliy@example.com"]

  spec.summary       = "First-class Inertia.js protocol adapter for Hanami 3.0"
  spec.description   = "Build modern Vue, React, and Svelte SPAs using Inertia.js with Hanami 3.0"
  spec.homepage      = "https://github.com/dbviewer/hanami-inertia"
  spec.license       = "MIT"
  spec.required_ruby_version = ">= 3.0.0"

  spec.files = Dir["lib/**/*.rb", "README.md", "LICENSE"]
  spec.require_paths = ["lib"]

  spec.add_dependency "hanami-controller", ">= 2.0"
  spec.add_dependency "json", ">= 2.0"
end
