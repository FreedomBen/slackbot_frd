require 'httparty'
require 'json'

module SlackbotFrd
  module SlackMethods
    class ImChannelsList
      include HTTParty
      base_uri 'https://slack.com/api/im.list'

      attr_reader :response

      def initialize(token)
        @token = token
      end

      def connect
        @response = JSON.parse(self.class.post('', :body => { token: @token } ).body)
        self
      end

      def ids_to_names
        retval = {}
        @response["ims"].each do |im|
          retval[im["id"]] = im["user"]
        end
        retval
      end

      def names_to_ids
        retval = {}
        @response["ims"].each do |im|
          retval[im["user"]] = im["id"]
        end
        retval
      end
    end
  end
end
