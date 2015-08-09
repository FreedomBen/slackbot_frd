require 'httparty'
require 'json'

module SlackbotFrd
  module SlackMethods
    class ChatDelete
      include HTTParty
      base_uri 'https://slack.com/api/chat.delete'

      def self.delete(token:, channel:, timestamp:)
        r = ChatDelete.new(token: token, channel: channel, timestamp: timestamp)
        r.delete
      end

      def initialize(token:, channel:, timestamp:)
        @token = token
        @channel = channel
        @timestamp = timestamp
      end

      def delete
        body = {
          token: @token,
          channel: @channel,
          ts: @timestamp,
        }

        @response = self.class.post('', :body => body)
        @response
      end
    end
  end
end
