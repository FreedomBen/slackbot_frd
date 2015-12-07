require 'httparty'
require 'json'

module SlackbotFrd
  module SlackMethods
    class ImOpen
      include HTTParty
      base_uri 'https://slack.com/api/im.open'

      def self.openChannel(token:, user:)
        r = ImOpen.new(
          token: token,
          user: user
        )
        r.openChannel
      end

      def initialize(token:, user:)
        @token = token
        @user = user
      end

      def openChannel
        body = {
          token: @token,
          user: @user
        }

        @response = self.class.post('', :body => body)
        @response.body
      end
    end
  end
end
