require 'httparty'
require 'json'

module SlackbotFrd
  module SlackMethods
    class ChatPostMessage
      include HTTParty
      base_uri 'https://slack.com/api/chat.postMessage'

      def self.postMessage(token, channel, message, username = nil, avatar = nil, avatar_is_emoji = nil)
        r = ChatPostMessage.new(token, channel, message, username, avatar, avatar_is_emoji)
        r.postMessage
      end

      def initialize(token, channel, message, username = nil, avatar = nil, avatar_is_emoji = nil)
        @token = token
        @channel = channel
        @message = message
        @username = username
        @avatar = avatar
        @avatar_is_emoji = avatar_is_emoji
      end

      def postMessage
        body = {
          token: @token,
          channel: @channel,
          text: @message,
        }

        if @username
          body.merge!({ username: @username })

          if @avatar_is_emoji
            body.merge!({ icon_emoji: @avatar })
          else
            body.merge!({ icon_url: @avatar })
          end
        else
          body.merge!({ as_user: true })
        end

        @response = self.class.post('', :body => body)
        @response
      end
    end
  end
end
