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
    PING_INTERVAL_SECONDS = 5

    attr_accessor :token

    def initialize(token:, errors_file:, monitor_connection: true)
      log_and_add_to_error_file("No token passed to #{self.class}") unless token

      @token = token
      @errors_file = errors_file
      @monitor_connection = monitor_connection

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

      @pong_received = true

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
          log_and_add_to_error_file(
            'No Real Time stream opened by slack.  Check for network connection and correct authentication token'
          )
          return
        end
        @ws = Faye::WebSocket::Client.new(wss_url)

        @on_connected_callbacks.each    { |callback| @ws.on(:open,  &callback) }
        @on_disconnected_callbacks.each { |callback| @ws.on(:close, &callback) }
        @ws.on(:message) { |event| process_message_received(event) }

        # Clean up our pid file
        @ws.on(:close) { |_event| File.delete(PID_FILE_NAME) }

        # This should ensure that we get a pong back at least every
        # PING_INTERVAL_SECONDS, otherwise we die because our
        # connection is probably toast
        EM.add_periodic_timer(PING_INTERVAL_SECONDS) { check_ping }
      end

      SlackbotFrd::Log.info("#{self.class}: event machine loop terminated")
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

    def on_message(user: :any, channel: :any, &block)
      wrap_user_or_channel_lookup_on_callback('on_message', user, channel) do
        @on_message_callbacks.add(
          user: user_name_to_id(user),
          channel: channel_name_to_id(channel),
          callback: block
        )
      end
    end

    def on_channel_left(user: :any, channel: :any, &block)
      wrap_user_or_channel_lookup_on_callback('on_message_channel_left', user, channel) do
        @on_channel_left_callbacks.add(
          user: user_name_to_id(user),
          channel: channel_name_to_id(channel),
          callback: block
        )
      end
    end

    def on_channel_joined(user: :any, channel: :any, &block)
      wrap_user_or_channel_lookup_on_callback('on_message_channel_joined', user, channel) do
        u = user_name_to_id(user)
        c = channel_name_to_id(channel)
        @on_channel_joined_callbacks.add(user: u, channel: c, callback: block)
      end
    end

    def send_im(user:, message:, username: nil, avatar_emoji: nil, avatar_url: nil)
      send_message(
        channel: im_channel_for_user(user: user),
        message: message,
        username: username,
        avatar_emoji: avatar_emoji,
        avatar_url: avatar_url,
        channel_is_id: true
      )
    end

    def send_message(
      channel:,
      message:,
      username: nil,
      avatar_emoji: nil,
      avatar_url: nil,
      channel_is_id: false,
      parse: 'full',
      thread_ts: nil,
      reply_broadcast: false
    )
      if (username && (avatar_emoji || avatar_url)) || parse != 'full'
        send_message_as_bot(
          channel: channel,
          message: message,
          username: username,
          avatar_emoji: avatar_emoji,
          avatar_url: avatar_url,
          channel_is_id: channel_is_id,
          parse: parse,
          thread_ts: thread_ts,
          reply_broadcast: reply_broadcast
        )
      else
        send_message_as_user(
          channel: channel,
          message: message,
          channel_is_id: channel_is_id,
          thread_ts: thread_ts,
          reply_broadcast: reply_broadcast
        )
      end
    end

    def delete_message(channel:, timestamp:)
      SlackbotFrd::Log.debug("#{self.class}: Deleting message with timestamp '#{timestamp}' from channel '#{channel}'")

      resp = SlackbotFrd::SlackMethods::ChatDelete.delete(
        token: @token,
        channel: channel_name_to_id(channel),
        timestamp: timestamp
      )

      SlackbotFrd::Log.debug("#{self.class}: Received response:  #{resp}")
    end

    def post_reaction(name:, channel: nil, timestamp: nil)
      SlackbotFrd::Log.debug(
        "#{self.class}: Posting reaction '#{name}' to channel '#{channel}' with timestamp '#{timestamp}'"
      )

      resp = SlackbotFrd::SlackMethods::ReactionsAdd.add(
        token: @token,
        name: name,
        channel: channel_name_to_id(channel),
        timestamp: timestamp
      )

      SlackbotFrd::Log.debug("#{self.class}: Received response:  #{resp}")
    end

    def invite_user(user:, channel:)
      SlackbotFrd::Log.debug(
        "#{self.class}: Inviting user '#{user}' to channel '#{channel}'"
      )

      resp = SlackbotFrd::SlackMethods::ChannelsInvite.invite(
        token: @token,
        user: user_name_to_id(user),
        channel: channel_name_to_id(channel)
      )

      SlackbotFrd::Log.debug("#{self.class}: Received response:  #{resp}")
    end

    def invite_user_to_group(user:, channel:)
      SlackbotFrd::Log.debug(
        "#{self.class}: Inviting user '#{user}' to channel '#{channel}'"
      )

      resp = SlackbotFrd::SlackMethods::GroupsInvite.invite(
        token: @token,
        user: user_name_to_id(user),
        channel: channel_name_to_id(channel)
      )

      SlackbotFrd::Log.debug("#{self.class}: Received response:  #{resp}")
    end

    def im_channel_for_user(user:)
      SlackbotFrd::Log.debug(
        "#{self.class}: Opening or retrieving IM channel for user '#{user}'"
      )

      resp = JSON.parse(SlackbotFrd::SlackMethods::ImOpen.openChannel(
        token: @token,
        user: user_name_to_id(user)
      ))

      SlackbotFrd::Log.debug("#{self.class}: Received response:  #{resp}")
      return resp["channel"]["id"] if resp["channel"]
      resp
    end

    def users_in_channel(channel)
      a = SlackMethods::ChannelsInfo.members(
        token: @token,
        channel: channel_name_to_id(channel)
      )
      a.map{ |id| user_id_to_name(id) }
    end

    def num_users_in_channel(channel)
      users_in_channel(channel).count
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
      unless @user_id_to_name && @user_id_to_name.key?(user_id)
        refresh_user_info
      end
      unless @user_id_to_name.include?(user_id)
        SlackbotFrd::Log.warn("#{self.class}: User id '#{user_id}' not found")
      end
      @user_id_to_name[user_id]
    end

    def user_name_to_id(user_name)
      return user_name if user_name == :any || user_name == :bot
      unless @user_name_to_id && @user_name_to_id.key?(user_name)
        refresh_user_info
      end
      unless @user_name_to_id.include?(user_name)
        SlackbotFrd::Log.warn(
          "#{self.class}: User name '#{user_name}' not found"
        )
      end
      @user_name_to_id[user_name]
    end

    def channel_id_to_name(channel_id)
      unless @channel_id_to_name && @channel_id_to_name.key?(channel_id)
        refresh_channel_info
      end
      unless @channel_id_to_name.include?(channel_id)
        SlackbotFrd::Log.warn(
          "#{self.class}: Channel id '#{channel_id}' not found"
        )
      end
      @channel_id_to_name[channel_id]
    end

    def channel_name_to_id(channel_name)
      return channel_name if channel_name == :any
      nc = normalize_channel_name(channel_name)
      unless @channel_name_to_id && @channel_name_to_id.key?(nc)
        refresh_channel_info
      end
      unless @channel_name_to_id.include?(nc)
        SlackbotFrd::Log.warn(
          "#{self.class}: Channel name '#{nc}' not found"
        )
      end
      @channel_name_to_id[nc]
    end

    def user_info(username)
      resp = SlackbotFrd::SlackMethods::UsersInfo.info(
        token: @token,
        user_id: user_name_to_id(username)
      )
    end

    private
    def send_message_as_user(
      channel:,
      message:,
      channel_is_id: false,
      thread_ts: nil,
      reply_broadcast: false
    )
      unless @ws
        log_and_add_to_error_file(
          "Cannot send message '#{message}' as user to channel '#{channel}' because not connected to wss stream"
        )
      end

      channel_id = channel_is_id ? channel : channel_name_to_id(channel)

      SlackbotFrd::Log.debug(
        "#{self.class}: Sending message '#{message}' as user to channel '#{channel}'"
      )

      begin
        resp = @ws.send({
          id: event_id,
          type: 'message',
          channel: channel_id,
          text: message,
          thread_ts: thread_ts,
          reply_broadcast: reply_broadcast
        }.to_json)

        SlackbotFrd::Log.debug("#{self.class}: Received response:  #{resp}")
      rescue SocketError => e
        log_and_add_to_error_file(socket_error_message(e))
      end
    end

    private
    def send_message_as_bot(
      channel:,
      message:,
      username: nil,
      avatar_emoji: nil,
      avatar_url: nil,
      parse: 'full',
      thread_ts: nil,
      reply_broadcast: false,
      channel_is_id: false
    )
      SlackbotFrd::Log.debug(
        "#{self.class}: Sending message '#{message}' as bot user '#{username}' to channel '#{channel}'"
      )

      channel_id = channel_is_id ? channel : channel_name_to_id(channel)

      resp = SlackbotFrd::SlackMethods::ChatPostMessage.postMessage(
        token: @token,
        channel: channel_id,
        message: message,
        username: username,
        avatar_emoji: avatar_emoji,
        avatar_url: avatar_url,
        parse: parse,
        thread_ts: thread_ts,
        reply_broadcast: reply_broadcast
      )

      SlackbotFrd::Log.debug("#{self.class}: Received response:  #{resp}")
    end

    private
    def wrap_user_or_channel_lookup_on_callback(callback_name, user, channel)
      begin
        return yield
      rescue SlackbotFrd::InvalidChannelError => _e
        log_and_add_to_error_file(
          "Unable to add #{callback_name} callback for channel '#{channel}'.  Lookup of channel name to ID failed.  Check network connection, and ensure channel exists and is accessible"
        )
      rescue SlackbotFrd::InvalidUserError => _e
        log_and_add_to_error_file(
          "Unable to add #{callback_name} callback for user '#{user}'.  Lookup of user name to ID failed.  Check network connection and ensure user exists"
        )
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

      return unless message['type'] == 'message'
      if message['subtype'] == 'channel_join'
        process_join_message(message)
      elsif message['subtype'] == 'channel_leave'
        process_leave_message(message)
      elsif message['subtype'] == 'file_share'
        process_file_share(message)
      else
        process_chat_message(message)
      end
    end

    private
    def process_file_share(message)
      SlackbotFrd::Log.verbose(
        "#{self.class}: Processing file share: #{message}"
      )
      SlackbotFrd::Log.debug(
        "#{self.class}: Not processing file share because it is not implemented:"
      )
    end

    private
    def extract_user(message)
      user = message['user']
      user = :bot if message['subtype'] == 'bot_message'
      user = message['message']['user'] if !user && message['message']
      user
    end

    private
    def extract_ts(message)
      ts = message['ts']
      ts = message['message']['ts'] if message['message'] && message['message']['ts']
      ts
    end

    private
    def extract_thread_ts(message)
      thread_ts = message['thread_ts']
      thread_ts = message['message']['thread_ts'] if message['message'] && message['message']['thread_ts']
      thread_ts
    end

    private
    def extract_text(message)
      text = message['text']
      text = message['message']['text'] if !text && message['message']
      text
    end

    private
    def process_chat_message(message)
      SlackbotFrd::Log.verbose("#{self.class}: Processing chat message: #{message}")

      user = extract_user(message)
      channel = message['channel']
      text = extract_text(message)
      ts = extract_ts(message)
      thread_ts = extract_thread_ts(message)

      unless user
        SlackbotFrd::Log.warn("#{self.class}: Chat message doesn't include user! message: #{message}")
        return
      end

      unless channel
        SlackbotFrd::Log.warn("#{self.class}: Chat message doesn't include channel! message: #{message}")
        return
      end

      @on_message_callbacks.where_include_all(user: user, channel: channel).each do |callback|
        # instance_exec allows the user to call send_message and send_message_as_user
        # without prefixing like this: slack_connection.send_message()
        #
        # However, it makes calling functions defined in the class not work, so
        # for now we aren't going to do it
        #
        #instance_exec(user_id_to_name(user), channel_id_to_name(channel), text, &callback)
        callback.call(
          user: user_id_to_name(user),
          channel: channel_id_to_name(channel),
          message: text,
          timestamp: ts,
          thread_ts: thread_ts
        )
      end
    end

    private
    def process_join_message(message)
      SlackbotFrd::Log.verbose("#{self.class}: Processing join message: #{message}")
      user = message['user']
      user = :bot if message['subtype'] == 'bot_message'
      channel = message['channel']
      @on_channel_joined_callbacks.where_include_all(user: user, channel: channel).each do |callback|
        callback.call(user: user_id_to_name(user), channel: channel_id_to_name(channel))
      end
    end

    private
    def process_leave_message(message)
      SlackbotFrd::Log.verbose("#{self.class}: Processing leave message: #{message}")
      user = message['user']
      user = :bot if message['subtype'] == 'bot_message'
      channel = message['channel']
      @on_channel_left_callbacks.where_include_all(user: user, channel: channel).each do |callback|
        callback.call(user: user_id_to_name(user), channel: channel_id_to_name(channel))
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

        groups_list = SlackbotFrd::SlackMethods::GroupsList.new(@token).connect
        @channel_id_to_name.merge!(groups_list.ids_to_names)
        @channel_name_to_id.merge!(groups_list.names_to_ids)
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

    private
    def check_ping
      @pong_received ? send_ping : die_from_no_pong
    end

    private
    def send_ping
      SlackbotFrd::Log.verbose('Sending ping')
      @pong_received = false
      @ws.ping do
        @pong_received = true
        SlackbotFrd::Log.verbose('Pong received')
      end
    end

    private
    def die_from_no_pong
      SlackbotFrd::Log.error(
        'Pong not received after 5 seconds.  Stopping EM loop...'
      )
      @ws.close
      EM.stop_event_loop
    end
  end
end
