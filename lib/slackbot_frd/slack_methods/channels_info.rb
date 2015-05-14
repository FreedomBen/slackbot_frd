require 'httparty'
require 'json'

module SlackbotFrd
  module SlackMethods
    class ChannelsInfo
      include HTTParty
      base_uri 'https://slack.com/api/channels.info'

      attr_reader :response

      def self.members(token, channel)
        ChannelsInfo.new(token, channel).connect.members
      end

      def initialize(token, channel)
        @token = token
        @channel = channel
      end

      def connect
        @response = JSON.parse(self.class.post('', :body => { token: @token, channel: @channel } ).body)
        self
      end

      def members
        if @response["channel"]
          @response["channel"]["members"]
        else
          []
        end
      end
      alias_method :users, :members
    end
  end
end
