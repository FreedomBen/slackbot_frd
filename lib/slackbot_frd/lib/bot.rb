# Subclass the bot class to have your bot loaded and run
module SlackbotFrd
  class Bot
    def self.only(*bots)
      @bots ||= []
      @bots.push(bots).flatten!
    end

    class << self
      attr_accessor :bots
    end

    # This is where the bot adds all of their callbacks to the bpbot
    def add_callbacks(slack_connection)
      raise StandardError.new("You must override the define() method for your bot to do anything")
    end
  end
end
