require 'faye/websocket'
require 'eventmachine'
require 'file-append'
require 'json'

require 'slackbot_frd/lib/errors'
require 'slackbot_frd/lib/user_channel_callbacks'
require 'slackbot_frd/lib/log'

require 'slackbot_frd/slack_methods/rtm_start'
require 'slackbot_frd/slack_methods/chat_post_message'
require 'slackbot_frd/slack_methods/im_channels_list'
require 'slackbot_frd/slack_methods/channels_list'
require 'slackbot_frd/slack_methods/channels_info'
require 'slackbot_frd/slack_methods/users_list'

module SlackbotFrd
  class SlackConnection
    FILE_PATH = File.expand_path(__FILE__)
    APP_ROOT = File.expand_path(File.dirname(File.dirname(FILE_PATH)))
    FILE_DIR = File.dirname(FILE_PATH)
    LOG_FILE = "#{APP_ROOT}/bp-slackbot.log"
    PID_FILE_NAME = "#{APP_ROOT}/bp-slackbot.pid"

    attr_accessor :token

    def initialize(token, errors_file)
      unless token
        log_and_add_to_error_file("No token passed to #{self.class}")
      end

      @token = token
      @errors_file = errors_file
      @event_id = 0
      @on_connected_callbacks = []
      @on_disconnected_callbacks = []
      @on_message_callbacks = UserChannelCallbacks.new
      @on_channel_left_callbacks = UserChannelCallbacks.new
      @on_channel_joined_callbacks = UserChannelCallbacks.new

      # These hashes are used to map ids to names efficiently
      @user_id_to_name = {}
      @user_name_to_id = {}
      @channel_id_to_name = {}
      @channel_name_to_id = {}

      restrict_actions_to_channels_joined
      SlackbotFrd::Log.debug("Done initializing #{self.class}")
    end

    def start
      # Write pid file
      File.write(PID_FILE_NAME, "#{Process.pid}")

      SlackbotFrd::Log.info("#{self.class}: starting event machine")

      EM.run do
        begin
          wss_url = SlackbotFrd::SlackMethods::RtmStart.wss_url(@token)
        rescue SocketError => e
          log_and_add_to_error_file(socket_error_message(e))
        end

        unless wss_url
          log_and_add_to_error_file("No Real Time stream opened by slack.  Check for network connection and correct authentication token")
          return
        end
        @ws = Faye::WebSocket::Client.new(wss_url)

        @on_connected_callbacks.each    { |callback| @ws.on(:open,  &callback) }
        @on_disconnected_callbacks.each { |callback| @ws.on(:close, &callback) }
        @ws.on(:message) { |event| process_message_received(event) }

        # Clean up our pid file
        @ws.on(:close) { |event| File.delete(PID_FILE_NAME) }
      end

      SlackbotFrd::Log.debug("#{self.class}: event machine started")
    end

    def event_id
      @event_id += 1
      @event_id
    end

    def on_connected(&block)
      @on_connected_callbacks.push(block)
    end

    def on_close(&block)
      @on_disconnected_callbacks.push(block)
    end

    def on_message(user = :any, channel = :any, &block)
      wrap_user_or_channel_lookup_on_callback('on_message', user, channel) do
        @on_message_callbacks.add(user_name_to_id(user), channel_name_to_id(channel), block)
      end
    end

    def on_channel_left(user = :any, channel = :any, &block)
      wrap_user_or_channel_lookup_on_callback('on_message_channel_left', user, channel) do
        @on_channel_left_callbacks.add(user_name_to_id(user), channel_name_to_id(channel), block)
      end
    end

    def on_channel_joined(user = :any, channel = :any, &block)
      wrap_user_or_channel_lookup_on_callback('on_message_channel_joined', user, channel) do
        u = user_name_to_id(user)
        c = channel_name_to_id(channel)
        @on_channel_joined_callbacks.add(u, c, block)
      end
    end

    def send_message(channel, message)
      unless @ws
        log_and_add_to_error_file("Cannot send message '#{message}' as user to channel '#{channel}' because not connected to wss stream")
      end

      SlackbotFrd::Log.debug("#{self.class}: Sending message '#{message}' as user to channel '#{channel}'")

      begin
        resp = @ws.send({
          id: event_id,
          type: "message",
          channel: channel_name_to_id(channel),
          text: message
        }.to_json)

        SlackbotFrd::Log.debug("#{self.class}: Received response:  #{resp}")
      rescue SocketError => e
        log_and_add_to_error_file(socket_error_message(e))
      end
    end

    def send_message_as_user(channel, message, username, avatar, avatar_is_emoji)
      SlackbotFrd::Log.debug("#{self.class}: Sending message '#{message}' as user '#{username}' to channel '#{channel}'")

      resp = SlackbotFrd::SlackMethods::ChatPostMessage.postMessage(
        @token,
        channel_name_to_id(channel),
        message,
        username,
        avatar,
        avatar_is_emoji
      )

      SlackbotFrd::Log.debug("#{self.class}: Received response:  #{resp}")
    end

    def invite_user(user, channel)
      SlackbotFrd::Log.debug("#{self.class}: Inviting user '#{user}' to channel '#{channel}'")

      resp = SlackbotFrd::SlackMethods::ChannelsInvite.invite(
        @token,
        user_name_to_id(user),
        channel_name_to_id(channel),
      )

      SlackbotFrd::Log.debug("#{self.class}: Received response:  #{resp}")
    end

    def restrict_actions_to_channels_joined(value = true)
      @restrict_actions_to_channels_joined = value
    end

    def users_in_channel(channel)
      a = SlackMethods::ChannelsInfo.members(@token, channel_name_to_id(channel))
      a.map{ |id| user_id_to_name(id) }
    end

    def user_ids(_force_refresh = false)
      @user_id_to_name.keys
    end

    def user_names(_force_refresh = false)
      @user_name_to_id.keys
    end

    def channel_ids(_force_refresh = false)
      @user_id_to_name.keys
    end

    def channel_names(_force_refresh = false)
      @channel_name_to_id.keys
    end

    def user_id_to_name(user_id)
      return user_id if user_id == :any || user_id == :bot
      unless @user_id_to_name && @user_id_to_name.has_key?(user_id)
        refresh_user_info
      end
      SlackbotFrd::Log.warn("#{self.class}: User id '#{user_id}' not found") unless @user_id_to_name.include?(user_id)
      @user_id_to_name[user_id]
    end

    def user_name_to_id(user_name)
      return user_name if user_name == :any || user_name == :bot
      unless @user_name_to_id && @user_name_to_id.has_key?(user_name)
        refresh_user_info
      end
      SlackbotFrd::Log.warn("#{self.class}: User name '#{user_name}' not found") unless @user_name_to_id.include?(user_name)
      @user_name_to_id[user_name]
    end

    def channel_id_to_name(channel_id)
      unless @channel_id_to_name && @channel_id_to_name.has_key?(channel_id)
        refresh_channel_info
      end
      SlackbotFrd::Log.warn("#{self.class}: Channel id '#{channel_id}' not found") unless @channel_id_to_name.include?(channel_id)
      @channel_id_to_name[channel_id]
    end

    def channel_name_to_id(channel_name)
      return channel_name if channel_name == :any
      nc = normalize_channel_name(channel_name)
      unless @channel_name_to_id && @channel_name_to_id.has_key?(nc)
        refresh_channel_info
      end
      SlackbotFrd::Log.warn("#{self.class}: Channel name '#{nc}' not found") unless @channel_name_to_id.include?(nc)
      @channel_name_to_id[nc]
    end

    private
    def wrap_user_or_channel_lookup_on_callback(callback_name, user, channel)
      begin
        return yield
      rescue SlackbotFrd::InvalidChannelError => e
        log_and_add_to_error_file("Unable to add #{callback_name} callback for channel '#{channel}'.  Lookup of channel name to ID failed.  Check network connection, and ensure channel exists and is accessible")
      rescue SlackbotFrd::InvalidUserError => e
        log_and_add_to_error_file("Unable to add #{callback_name} callback for user '#{user}'.  Lookup of channel name to ID failed.  Check network connection and ensure user exists")
      end
    end

    private
    def normalize_channel_name(channel_name)
      return channel_name[1..-1] if channel_name.start_with?('#')
      channel_name
    end

    private
    def process_message_received(event)
      message = JSON.parse(event.data)
      SlackbotFrd::Log.verbose("#{self.class}: Message received: #{message}")
      if message["type"] == "message"
        if message["subtype"] == "channel_join"
          process_join_message(message)
        elsif message["subtype"] == "channel_leave"
          process_leave_message(message)
        elsif message["subtype"] == "file_share"
          process_file_share(message)
        else
          process_chat_message(message)
        end
      end
    end

    private
    def process_file_share(message)
      SlackbotFrd::Log.verbose("#{self.class}: Processing file share: #{message}")
      SlackbotFrd::Log.debug("#{self.class}: Not processing file share because it is not implemented:")
    end

    private
    def process_chat_message(message)
      SlackbotFrd::Log.verbose("#{self.class}: Processing chat message: #{message}")

      user = message["user"]
      user = :bot if message["subtype"] == "bot_message"
      channel = message["channel"]
      text = message["text"]

      unless user
        SlackbotFrd::Log.warn("#{self.class}: Chat message doesn't include user! message: #{message}")
        return
      end

      unless channel
        SlackbotFrd::Log.warn("#{self.class}: Chat message doesn't include channel! message: #{message}")
        return
      end

      @on_message_callbacks.where_include_all(user, channel).each do |callback|
        # instance_exec allows the user to call send_message and send_message_as_user
        # without prefixing like this: slack_connection.send_message()
        #  
        # However, it makes calling functions defined in the class not work, so
        # for now we aren't going to do it
        #
        #instance_exec(user_id_to_name(user), channel_id_to_name(channel), text, &callback)
        callback.call(user_id_to_name(user), channel_id_to_name(channel), text)
      end
    end

    private
    def process_join_message(message)
      SlackbotFrd::Log.verbose("#{self.class}: Processing join message: #{message}")
      user = message["user"]
      user = :bot if message["subtype"] == "bot_message"
      channel = message["channel"]
      @on_channel_joined_callbacks.where_include_all(user, channel).each do |callback|
        callback.call(user_id_to_name(user), channel_id_to_name(channel))
      end
    end

    private
    def process_leave_message(message)
      SlackbotFrd::Log.verbose("#{self.class}: Processing leave message: #{message}")
      user = message["user"]
      user = :bot if message["subtype"] == "bot_message"
      channel = message["channel"]
      @on_channel_left_callbacks.where_include_all(user, channel).each do |callback|
        callback.call(user_id_to_name(user), channel_id_to_name(channel))
      end
    end

    private
    def refresh_user_info
      begin
        users_list = SlackbotFrd::SlackMethods::UsersList.new(@token).connect
        @user_id_to_name = users_list.ids_to_names
        @user_name_to_id = users_list.names_to_ids
      rescue SocketError => e
        log_and_add_to_error_file(socket_error_message(e))
      end
    end

    private
    def refresh_channel_info
      begin
        channels_list = SlackbotFrd::SlackMethods::ChannelsList.new(@token).connect
        @channel_id_to_name = channels_list.ids_to_names
        @channel_name_to_id = channels_list.names_to_ids

        im_channels_list = SlackbotFrd::SlackMethods::ImChannelsList.new(@token).connect
        @channel_id_to_name.merge!(im_channels_list.ids_to_names)
        @channel_name_to_id.merge!(im_channels_list.names_to_ids)
      rescue SocketError => e
        log_and_add_to_error_file(socket_error_message(e))
      end
    end

    private
    def socket_error_message(e)
      "SocketError: Check your connection: #{e.message}"
    end

    private
    def log_and_add_to_error_file(err)
      SlackbotFrd::Log.error(err)
      File.append(@errors_file, "#{err}\n")
    end
  end
end
