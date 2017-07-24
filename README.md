# Slackbot FRD (Slackbot For Realz Dude)

[![Gem Version](https://badge.fury.io/rb/slackbot_frd.svg)](https://badge.fury.io/rb/slackbot_frd) [![Code Climate](https://codeclimate.com/github/FreedomBen/slackbot_frd/badges/gpa.svg)](https://codeclimate.com/github/FreedomBen/slackbot_frd) [![Dependency Status](https://gemnasium.com/badges/github.com/FreedomBen/slackbot_frd.svg)](https://gemnasium.com/github.com/FreedomBen/slackbot_frd) [![Dependency Status](https://dependencyci.com/github/FreedomBen/slackbot_frd/badge)](https://dependencyci.com/github/FreedomBen/slakcbot_frd)

tl;dr:  This is a ruby framework that makes it easy to write bots that talk on [Slack](https://slack.com/).  It puts rails to shame.  Requires Ruby 2.1 or newer.

The slack web api is good, but very raw.  What you need is a great ruby framework to abstract away all that.  This is it!  This framework allows you to write bots easily by providing methods that are easy to call.  Behind the scenes, the framework is negotiating your real time stream, converting channel names and user names to and from IDs so you can use the names instead, and parsing/classifying the real time messages into useful types that you can hook into.  Don't write your bot without this.

## Why use this framework

* This makes writing one or more bots trivial
* You get to use the Slack Real-Time Messaging (RTM) API for free - no bothering with setting up and maintaining an active wss connection
    * The connection to slack is automatically initialized and ping/ponged for you
    * If the connection goes down, it is automatically brought back up
* Running your bots continuously is handled for you
    * This means you can run your bots as a system service
    * When the connection goes down, it is brought back up for you
* Extensive logging is built in
* The Slack API is abstracted into easy ruby methods that take blocks
* Ruby is better than javascript

## Quick Reference:
(Getting Started information can be found [below](#prestantious--eximious--how-do-i-start)):

### Events
Here are events that you may wish to listen for (put inside your `add_callbacks(slack_connection)` method in your `Bot` subclass:

    class ExampleBot < SlackbotFrd::Bot
        def add_callbacks(slack_connection)

            # Pass a block that handles your response
            slack_connection.on_connected do
            slack_connection.on_close do
            slack_connection.on_message do |user:, channel:, timestamp:, thread_ts:|
            slack_connection.on_channel_joined() do |user:, channel:|
            slack_connection.on_channel_left do |user:, channel:|

        end
    end

### Responses

Here are responses through the slack connection you may wish to use:

    def add_callbacks(slack_connection)
        slack_connection.on_message do |user:, channel:, timestamp:, thread_ts:|

            slack_connection.send_message(message:, channel:, thread_ts: nil)
            slack_connection.send_message(message:, channel:, username:, avatar_emoji:, thread_ts: nil)
            slack_connection.send_message(message:, channel:, username:, avatar_url:, thread_ts: nil)

            slack_connection.delete_message(channel:, timestamp:)
            slack_connection.post_reaction(name:, channel:, timestamp:)
            slack_connection.invite_user(user:, channel:)

        end
    end

The `thread_ts` parameter is how you send your message as a reply in a thread versus
in the regular channel, and how you can tell if the message received is part of a thread.
The `thread_ts` value passed into your `on_message` listener will be populated if the
message was part of a thread.  To reply as part of the thread, `thread_ts` should be
the timestamp of the root of the thread.

### Data retrieval

Here are some handles through which you can get useful data:

    def add_callbacks(slack_connection)
        slack_connection.on_message do |user:, channel:, timestamp:|

            slack_connection.user_in_channel(channel)
            slack_connection.user_ids
            slack_connection.user_names
            slack_connection.channel_ids
            slack_connection.channel_names

        end
    end

## Prestantious!  Eximious!  How do I start?

### Step 1

First, get a slack API token.  You can usually do this as your regular user unless restricted, or (if you have admin powers) you can create a bot user.

To get a token as your regular user, go to [https://api.slack.com/web](https://api.slack.com/web), scroll down to "Authentication," then issue yourself a token.

Or to make a bot user, go [here](https://my.slack.com/services/new/bot) and do the dance to make a bot user.  Copy the bot user's token for later.

### Step 2

All slackbot_frd needs is to be configured and told where the bot files are.  However, a sample project with config files can be created to give you an easy starting point.

You can generate an example bot using the `slackbot-frd` binary:

    slackbot-frd new <proj-name>

This is nice (but optional) cause you can just edit the generated files and be on your way quickly.

You have 3 options for configuring slackbot_frd.  In the event that you do more than one of these, the *latter* one will trump (In other words, if you have a config file *and* environment variables set, the environment variables will win out (see [below](#configuration-options) for an enumeration of config options):

1. A config file called  'slackbot-frd.conf' in your top level directory
    * Can also be specified on the command line by with --config-file
    * Is parsed as JSON.
    * All portions are optional except token (unless token is specified elsewhere)
    * If JSON doesn't contain "bots" then all bots will be run
    * All config options are available to your bots through the global variable '$slackbotfrd_conf', so you can put stuff here (like an API key for your bot's functionality)
    * Example: 

        ```
        {
            "token" : "<your-token>",
            "botdir" : ".",
            "daemonize" : false,
            "bots" : [
                "EchoBot",
                "GreetingBot"
            ],
            "log_level" : "debug",
            "log_file" : "my-cool-bot.log",
            "my_bots_config_option" : "<bot-specific-option>"
        }
        ```

2. Environment variables
    * `SLACKBOT_FRD_TOKEN="<your-token>"`
    * `SLACKBOT_FRD_BOTDIR="/directory/containing/bots"`
    * `SLACKBOT_FRD_DAEMONIZE="y"  # Any non-null value works here`
    * `SLACKBOT_FRD_LOG_LEVEL="info"`
    * `SLACKBOT_FRD_LOG_FILE="my-cool-bot.log"`
3. Command line arguments
    * `slackbot-frd start --daemonize --token="<your-token>" --botdir="." --log-level="info" --log-file="my-cool-bot.log"`

### Step 3

Install this gem:

    gem install slackbot_frd

### Step 4

Subclass `SlackbotFrd::Bot` and do something cool.  Here's the entire implementation for an annoying bot that just echoes what you say (More [details below](#subclassing-bot)):

    require 'slackbot_frd'

    class EchoBot < SlackbotFrd::Bot
      def add_callbacks(slack_connection)
        slack_connection.on_message do |user:, channel:, message:|
          slack_connection.send_message(channel: channel, message: message) if user != :bot
        end
      end
    end

### Step 5

Start your bot(s):

    slackbot-frd start [any-flags] [optional list of bots to start]

Stop them later (if in daemonize mode):

    slackbot-frd stop

## Configuration options

The following configuration options are available.  Where applicable, defaults are noted:

<table>
    <tr>
        <td>Option</td>
        <td>Config File Var Name</td>
        <td>Environment Var</td>
        <td>Command Line Flag</td>
        <td>Default val</td>
        <td>Description</td>
    </tr>
    <tr>
        <td>Slack API token</td>
        <td>"token"</td>
        <td>SLACKBOT_FRD_TOKEN</td>
        <td>-t or --token</td>
        <td>None</td>
        <td>The API token for use with slack.  This is required.</td>
    </tr>
    <tr>
        <td>Top level of bot directory</td>
        <td>"botdir"</td>
        <td>SLACKBOT_FRD_BOTDIR</td>
        <td>-b or --botdir</td>
        <td>current working dir</td>
        <td>This is the top level of the bot directory.  This directory and it's subs will be loaded in to the ruby environment</td>
    </tr>
    <tr>
        <td>Daemonize</td>
        <td>"daemonize"</td>
        <td>SLACKBOT_FRD_DAEMONIZE</td>
        <td>-d or --daemonize</td>
        <td>false</td>
        <td>if true, the connection watcher will be run as a daemon process</td>
    </tr>
    <tr>
        <td>Bots to run</td>
        <td>"bots"</td>
        <td>No env var</td>
        <td>specified as extra args with no flags</td>
        <td>all</td>
        <td>These are the bots that will be run by the framework</td>
    </tr>
    <tr>
        <td>Log level</td>
        <td>"log_level"</td>
        <td>SLACKBOT_FRD_LOG_LEVEL</td>
        <td>-ll or --log-level</td>
        <td>info</td>
        <td>This sets the log level of the framework</td>
    </tr>
    <tr>
        <td>Log file</td>
        <td>"log_file"</td>
        <td>SLACKBOT_FRD_LOG_FILE</td>
        <td>-lf or --log-file</td>
        <td>my-cool-bot.log</td>
        <td>This sets the log file used by the framework</td>
    </tr>
</table>

## Subclassing Bot

In your subclass of `SlackbotFrd::Bot`, you will need to override the `add_callbacks` method which takes one argument, commonly called `slack_connection` (or `sc` for short).

    def add_callbacks(slack_connection)

All of your bot's actions (such as listening for and responding to events) will be taken through this object.  The most common thing you'll want to do is listen for an incoming chat message:

    slack_connection.on_message do |user:, channel:, message:|

You can also pass two arguments (user:, channel:) to filter which messages trigger this callback.  For example, if you only wanted to respond to messages from user "Derek," and only in channel #games,  it would be:

    slack_connection.on_message(user: 'derek', channel: 'games') do |user:, channel:, message:, timestamp:|

You can also pass the symbol `:any` to match any user or any channel.

The arguments passed to your block are the 'user' (The user's username), the 'channel', (the channel name without the leading #), and the 'message', (the text of the message).  If the message was posted by a bot, then 'user' will equal `:bot`.

You can respond to events by sending messages through the slack_connection.  if username and avatar are not specified, the message is posted as the user who owns the token (so your bot user if you're running as a bot, or your actual user if you are running as yourself).  NOTE: You only specify either an emoji for your avatar or a URL.  If you specify both, it's going to show up as the emoji:

    slack_connection.send_message(
      channel: channel,
      message: message,
      username: username,
      avatar_emoji: avatar_emoji,  # specify either an emoji or a url, but not both
      avatar_url: avatar_url
    )

Here are events that you may wish to listen for:

    on_connected()
    on_close()
    on_message(user:, channel:, timestamp:)
    on_channel_joined(user:, channel:)
    on_channel_left(user:, channel:)

And here are responses through the slack connection you may wish to use:

    slack_connection.send_message(message:, channel:)
    slack_connection.send_message(message:, channel:, username:, avatar_emoji:)
    slack_connection.send_message(message:, channel:, username:, avatar_url:)

    slack_connection.delete_message(channel:, timestamp:)
    slack_connection.post_reaction(name:, channel:, timestamp:)
    slack_connection.invite_user(user:, channel:)

And here are some handles through which you can get useful data:

    slack_connection.user_in_channel(channel)
    slack_connection.user_ids
    slack_connection.user_names
    slack_connection.channel_ids
    slack_connection.channel_names

## Directly calling slack methods

If you are going ultra simple and just want to make api calls without establishing a real-time-messaging session, you can use the slack methods available in `slackbot_frd/lib/slack_methods/` directly.  These are named directly after [web api methods provided by the slack REST API](https://api.slack.com/methods).  For example, here's a regular ruby script that posts to a given channel using the [chat.postMessage](https://api.slack.com/methods/chat.postMessage) method:

    #!/usr/bin/env ruby

    # Can also just `require 'slackbot_frd'` if you want to be lazy
    # and don't care about loading more than you need
    require 'slackbot_frd/lib/slack_methods/chat_post_message'

    SlackbotFrd::SlackMethods::ChatPostMessage.postMessage(
        token: '<dis-be-my-token-sucka>',
        channel: '#fun_room',                   # channel to post to
        message: 'Oh, ah, ah, ah, ah',          # Text to post
        username: 'Down With The Sickness Bot', # Name of your bot
        avatar_emoji: ':devil:'                 # emoji to use as your bot's avatar
    )

This simple method can give you a lot of power.  For instance, I use this at work to post reminders for daily standups.  I just call the script from a [cron](http://en.wikipedia.org/wiki/Cron) job.

## Cool Tricks

### Posting as a bot using your regular user token

You can post a chat message that appears to come from a "bot," using only your user's API token!  Don't be stupid though.  If you do something irresponsible it can easily be tracked back to you.

* From inside a "slack_connection" (such as the one passed to your `SlackbotFrd::Bot` subclass):

    ```
    slack_connection.send_message(
        channel: channel,
        message: message,
        username: username_to_show,
        avatar_emoji: avatar_emoji  # or avatar_url: avatar_url if using a URL
    )
    ```

* Directly using `ChatPostMessage`:

    ```
    SlackbotFrd::SlackMethods::ChatPostMessage.postMessage(
        channel: channel,
        message: message,
        username: username_to_show,
        avatar_emoji: avatar_emoji  # or avatar_url: avatar_url if using a URL
    )
    ```

## Sample Projects

Sample project number one is [simple_rafflebot](https://github.com/FreedomBen/simple_rafflebot), a trivial "Raffle Bot" that responds to any message that starts with "rafflebot" by getting a list of users in the channel and randomly picking a "winner" from the list.  You can find it here:  https://github.com/FreedomBen/simple_rafflebot

Sample project number two is [rafflebot](https://github.com/FreedomBen/rafflebot), which expands on simple_rafflebot by adding some nice features.  This project includes a sqlite database to persist data.

## How do I set up incoming/outgoing webhooks with this?

This framework uses the Real-time Messaging API from slack, which is much more powerful than incoming/outgoing webhooks, and require less configuration.  If you want to use incoming/outgoing webhooks, I suggest either rails or sinatra.  Note that in order to set up hooks, you will need to have admin powers or be granted that permission by an admin.

## Bugs, Features, and Contributions

This is a very young and incomplete project, but I am striving to keep the docs up to date.  Please open bugs and send pull requests!
