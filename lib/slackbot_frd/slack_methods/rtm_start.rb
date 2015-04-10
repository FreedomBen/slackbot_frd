require 'httparty'
require 'json'

module SlackbotFrd
  module SlackMethods
    class RtmStart
      include HTTParty
      base_uri 'https://slack.com/api/rtm.start'

      def self.wss_url(token)
        r = RtmStart.new(token)
        r.connect
        r.wss_url
      end

      def initialize(token)
        @token = token
      end

      def connect
        @response = JSON.parse(self.class.post('', :body => { token: @token } ).body)
        @response
      end

      def wss_url
        #return "ERR" unless @response.has_key?("url")
        @response["url"]
      end
    end
  end
end
