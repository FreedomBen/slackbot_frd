require 'httparty'
require 'json'

module SlackbotFrd
  module SlackMethods
    module ValidateSlack
      def self.response(response)
        if response['ok']
          response
        else
          msg = if response['error']
                  response['error']
                else
                  'Slack returned an error'
                end
          raise StandardError.new("#{msg} - response: #{response}")
        end
      end
    end
  end
end
