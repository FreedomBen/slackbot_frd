require 'httparty'
require 'json'

module SlackbotFrd
  module SlackMethods
    class UsersInfo
      include HTTParty
      base_uri 'https://slack.com/api/users.info'

      attr_reader :response

      def self.info(token:, user_id:)
        UsersInfo.new(token: token, user_id: user_id).connect.info
      end

      def initialize(token:, user_id:)
        @token = token
        @user_id = user_id
      end

      def connect
        @response = JSON.parse(self.class.post('', :body => { token: @token, user: @user_id } ).body)
        self
      end

      def info
        @response["user"]
      end
    end
  end
end
