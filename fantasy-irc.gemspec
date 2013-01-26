Gem::Specification.new do |s|
  s.authors           = ["Jens Becker"]
  s.email             = ["v2px@v2px.de"]
  s.description       = "A modular, event-driven IRC client/bot gem for Ruby with plugin support"
  s.summary           = "A modular, event-driven IRC client/bot gem for Ruby with plugin support"
  s.homepage          = "https://github.com/v2px/fantasy-irc"

  s.files             = `git ls-files`.split("\n")
  s.name              = "fantasy-irc"
  s.require_paths     = ['lib']
  s.version           = "0.1.0"

  s.rubyforge_project = s.name
  s.add_runtime_dependency "array-unique", "~> 1.1.1"
end
