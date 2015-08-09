require 'slackbot_frd/lib/log'

module SlackbotFrd
  class UserChannelCallbacks
    def initialize
      @conditions = {}
      @conditions[:any] = {}
      @conditions[:any][:any] = []
    end

    def init(user:, channel:)
      unless user
        Log::error("#{self.class}: Invalid user '#{user}'")
        raise InvalidUserError.new
      end
      unless channel
        Log::error("#{self.class}: Invalid channel '#{channel}'")
        raise InvalidChannelError.new
      end
      @conditions[user] ||= {}
      @conditions[user][:any] ||= []
      @conditions[:any][channel] ||= []
      @conditions[user][channel] ||= []
    end

    def add(user:, channel:, callback:)
      init(user: user, channel: channel)
      @conditions[user][channel].push(callback)
    end

    def where(user:, channel:)
      init(user: user, channel: channel)
      @conditions[user][channel] || []
    end

    def where_all
      @conditions[:any][:any] || []
    end

    def where_include_all(user:, channel:)
      init(user: user, channel: channel)
      retval = @conditions[:any][:any].dup || []
      retval.concat(@conditions[user][:any] || [])
      retval.concat(@conditions[:any][channel] || [])
      retval.concat(@conditions[user][channel] || [])
      retval
    end

    def to_s
      "#{@conditions}"
    end
  end
end
