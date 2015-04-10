require 'slackbot_frd/initializer/bot_starter'

class BotStarterCli < Thor
  option :token, type: :string, required: true, aliases: 't'
  option :botdir, type: :string, required: true, aliases: ['b', 'd']
  def start(*bots)
    BotStarter.start_bots(options[:token], options[:botdir], bots)
  end
end

BotStarterCli.start(ARGV)
