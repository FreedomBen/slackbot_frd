#!/usr/bin/env ruby

require 'file-append'
require 'thor'

require 'slackbot_frd/lib/slack_connection'
require 'slackbot_frd/lib/bot'

begin
  require 'byebug'
rescue LoadError
end

class BotStarter
  def self.start_bots(errors_file, token, botdir, bots)
    bot_enabled = ->(bot) { bots.empty? || bots.include?(bot) }

    # Create a new Connection to pass to the bot classes
    slack_connection = SlackbotFrd::SlackConnection.new(token, errors_file)

    load_bot_files(botdir)

    bots = []
    # instantiate them, and then call their add_callbacks method
    ObjectSpace.each_object(Class).select do |klass|
      if klass != SlackbotFrd::Bot && klass.ancestors.include?(SlackbotFrd::Bot) && bot_enabled.call(klass.name)
        SlackbotFrd::Log.debug("Instantiating class '#{klass.to_s}'")
        b = klass.new
        SlackbotFrd::Log.debug("Adding callbacks to bot '#{klass}'")
        b.add_callbacks(slack_connection)
        bots.push(b)
      end
    end

    if bots.count == 0
      SlackbotFrd::Log.error("Not starting: no bots found")
      File.append(errors_file, "Not starting: no bots found")
    else
      SlackbotFrd::Log.debug("Starting SlackConnection")
      slack_connection.start
      SlackbotFrd::Log.debug("Connection closed")
    end
  end

  private
  def self.load_bot_files(top_level_dir)
    Dir["#{File.expand_path(top_level_dir)}/**/*.rb"].each do |f|
      SlackbotFrd::Log.debug("Loading bot file '#{f}'")
      load(f)
    end
  end
end
