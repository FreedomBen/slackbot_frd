require 'httparty'
require 'json'

module SlackbotFrd
  module SlackMethods
    class GroupsList
      include HTTParty
      base_uri 'https://slack.com/api/groups.list'

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
        @response["groups"].each do |group|
          retval[group["id"]] = group["name"]
        end
        retval
      end

      def names_to_ids
        retval = {}
        @response["groups"].each do |group|
          retval[group["name"]] = group["id"]
        end
        retval
      end
    end
  end
end
