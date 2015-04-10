
module SlackbotFrd
  class NoTokenError < StandardError
    def initialize(message = nil)
      if message
        super(message)
      else
        super("An API token is required for authenticating to the Slack API")
      end
    end
  end

  class AuthenticationFailedError < StandardError
  end

  class InvalidUserError < StandardError
  end

  class InvalidChannelError < StandardError
  end
end
