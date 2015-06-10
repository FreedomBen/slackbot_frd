require 'httparty'
require 'json'

module SlackbotFrd
  module SlackMethods
    class ChannelsInvite
      include HTTParty
      base_uri 'https://slack.com/api/channels.invite'

      attr_reader :response

      def self.invite(token, user, channel)
        ChannelsInvite.new(token, user, channel).run
      end

      def initialize(token, user, channel)
        @token = token
        @user = user
        @channel = channel
      end

      def run
        @response = JSON.parse(
          self.class.post(
            '',
            body: {
              token: @token, channel: @channel, user: @user
            }
          ).body
        )
        @response
      end
    end
  end
end
