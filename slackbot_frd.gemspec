# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'slackbot_frd/lib/version'

Gem::Specification.new do |s|
  s.name        = 'slackbot_frd'
  s.version     = SlackbotFrd::VERSION
  s.date        = SlackbotFrd::DATE
  s.summary     = 'slackbot_frd provides a dirt-simple framework ' \
    'for implementing one or more slack bots'
  s.description = 'The slack web api is good, but very raw.  ' \
    'What you need is a great ruby framework to abstract away all ' \
    'that.  This is it!  This framework allows you to write bots ' \
    'easily by providing methods that are easy to call.  Behind ' \
    'the scenes, the framework is negotiating your real time ' \
    'stream, converting channel names and user names to and from ' \
    'IDs so you can use the names instead, and parsing/classifying ' \
    'the real time messages into useful types that you can hook ' \
    "into.  Don't write your bot without this."
  s.authors     = ['Ben Porter']
  s.email       = 'BenjaminPorter86@gmail.com'
  s.files       = ['lib/slackbot_frd.rb'] + Dir['lib/slackbot_frd/**/*']
  s.homepage    = 'https://github.com/FreedomBen/slackbot_frd'
  s.license     = 'MIT'

  s.executables << 'slackbot-frd'

  s.add_runtime_dependency 'activesupport', '~> 6.1'
  s.add_runtime_dependency 'httparty', '~> 0.20'
  s.add_runtime_dependency 'faye-websocket', '~> 0.11'
  s.add_runtime_dependency 'colorize', '~> 0.8'
  s.add_runtime_dependency 'thor', '~> 1.1'
  s.add_runtime_dependency 'json', '~> 2.6'
  s.add_runtime_dependency 'file-append', '~> 0.0'
  s.add_runtime_dependency 'ptools', '~> 1.4'

  s.add_development_dependency 'byebug', '~> 11.1'
  s.add_development_dependency 'rspec', '~> 3.10'
end
