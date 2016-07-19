require 'httparty'
require 'json'

module SlackbotFrd
  module SlackMethods
    class ChannelsList
      include HTTParty
      base_uri 'https://slack.com/api/channels.list'

      attr_reader :response

      def initialize(token)
        @token = token
      end

      def connect
        @response = JSON.parse(self.class.post('', :body => { token: @token } ).body)
        ValidateSlack.response(@response)
        self
      end

      def ids_to_names
        retval = {}
        @response['channels'].each do |channel|
          retval[channel['id']] = channel['name']
        end
        retval
      end

      def names_to_ids
        retval = {}
        @response['channels'].each do |channel|
          retval[channel['name']] = channel['id']
        end
        retval
      end
    end
  end
end
