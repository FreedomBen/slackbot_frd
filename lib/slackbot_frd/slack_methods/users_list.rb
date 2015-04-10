require 'httparty'
require 'json'

module SlackbotFrd
  module SlackMethods
    class UsersList
      include HTTParty
      base_uri 'https://slack.com/api/users.list'

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
        @response["members"].each do |user|
          retval[user["id"]] = user["name"]
        end
        retval
      end

      def names_to_ids
        retval = {}
        @response["members"].each do |user|
          retval[user["name"]] = user["id"]
        end
        retval
      end
    end
  end
end
