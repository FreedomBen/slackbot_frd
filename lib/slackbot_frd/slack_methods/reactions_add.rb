require 'httparty'
require 'json'

module SlackbotFrd
  module SlackMethods
    class ReactionsAdd
      include HTTParty
      base_uri 'https://slack.com/api/reactions.add'

      def self.add(token:, name:, channel: nil, timestamp: nil)
        r = ReactionsAdd.new(token: token, name: name, channel: channel, timestamp: timestamp)
        r.add
      end

      def initialize(token:, name:, channel: nil, timestamp: nil)
        @token = token
        @name = name
        @channel = channel
        @timestamp = timestamp
      end

      def add
        body = {
          token: @token,
          name: @name
        }

        if @channel && @timestamp
          body.merge!({
            channel: @channel,
            timestamp: @timestamp
          })
        end

        @response = self.class.post('', :body => body)
        ValidateSlack.response(@response)
        @response
      end
    end
  end
end
