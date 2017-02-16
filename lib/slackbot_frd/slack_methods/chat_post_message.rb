require 'httparty'
require 'json'

module SlackbotFrd
  module SlackMethods
    class ChatPostMessage
      include HTTParty
      base_uri 'https://slack.com/api/chat.postMessage'

      def self.postMessage(
        token:,
        channel:,
        message:,
        username: nil,
        avatar_emoji: nil,
        avatar_url: nil,
        parse: 'full',
        thread_ts: nil,
        reply_broadcast: false
      )
        r = ChatPostMessage.new(
          token: token,
          channel: channel,
          message: message,
          username: username,
          avatar_emoji: avatar_emoji,
          avatar_url: avatar_url,
          parse: parse,
          thread_ts: thread_ts,
          reply_broadcast: reply_broadcast
        )
        r.postMessage
      end

      def initialize(
        token:,
        channel:,
        message:,
        username: nil,
        avatar_emoji: nil,
        avatar_url: nil,
        parse: 'full',
        thread_ts: nil,
        reply_broadcast: false
      )
        @token = token
        @channel = channel
        @message = message
        @username = username
        @avatar_emoji = avatar_emoji
        @avatar_url = avatar_url
        @parse = parse
        @thread_ts = thread_ts
        @reply_broadcast = reply_broadcast
      end

      def postMessage
        body = {
          token: @token,
          channel: @channel,
          text: @message,
        }

        if @username
          body.merge!({ username: @username })

          if @avatar_emoji
            body.merge!({ icon_emoji: @avatar_emoji })
          else
            body.merge!({ icon_url: @avatar })
          end
        else
          body.merge!({ as_user: true })
        end

        body.merge!(parse: @parse) if @parse
        body.merge!(thread_ts: @thread_ts, reply_broadcast: @reply_broadcast) if @thread_ts

        @response = self.class.post('', :body => body)
        ValidateSlack.response(@response)
        @response
      end
    end
  end
end
