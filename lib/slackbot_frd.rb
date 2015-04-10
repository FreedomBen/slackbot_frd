Gem.find_files("slackbot_frd/**/*.rb").each do |path|
  require path.gsub(/\.rb$/, '') unless path =~ /bot.*cli/
end
