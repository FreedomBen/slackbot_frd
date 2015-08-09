# Slackbot FRD (Slackbot For Realz Dude)

tl;dr:  This is a ruby framework that makes it easy to write bots that talk on [Slack](https://slack.com/).  It puts rails to shame.

The slack web api is good, but very raw.  What you need is a great ruby framework to abstract away all that.  This is it!  This framework allows you to write bots easily by providing methods that are easy to call.  Behind the scenes, the framework is negotiating your real time stream, converting channel names and user names to and from IDs so you can use the names instead, and parsing/classifying the real time messages into useful types that you can hook into.  Don't write your bot without this.

## Why use this framework

* Writing one or more bots is trivial
* You don't have to worry about using event machine and setting up the real time stream
* Running your bots continuously is handled for you
    * This means you can run your bots as a system service
    * When the connection goes down, it is brought back up for you
* Extensive logging is built in
* The Slack API is abstracted into easy ruby methods that take a block
* Ruby is better than javascript

## Prestantious!  Eximious!  How do I start?

### Step 1

First, get a slack API token.  You can do this as your regular user, or (if you have admin powers) you can create a bot user.

To get a token as your regular user, go to [https://api.slack.com/web](https://api.slack.com/web), scroll down to "Authentication," then issue yourself a token.

Go [here](https://my.slack.com/services/new/bot) and do the dance to make a bot user.  Copy the bot user's token for later.

### Step 2

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
        slack_connection.on_message do |user, channel, message|
          slack_connection.send_message_as_user(channel, message) if user != :bot
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

In your subclass of `SlackbotFrd::Bot`, you will need to override the `add_callbacks` method which takes one argument, commonly call `slack_connection` (or `sc` for short).

    def add_callbacks(slack_connection)

All of your bot's actions (such as listening for and responding to events) will be taken through this object.  The most common thing you'll want to do is listen for an incoming chat message:

    slack_connection.on_message(:any, :any) do |user, channel, message|

or more simply (these are equivalent)

    slack_connection.on_message do |user, channel, message|

The two arguments you see passed (:any, :any) are ways to filter which messages trigger this callback.  The first argument is for user, and the second is for channel.  For example, if you only wanted to respond to messages from user "Derek," and only in channel #games,  it would be:

    slack_connection.on_message('derek', 'games') do |user, channel, message|

The arguments passed to your block are the 'user' (The username), the 'channel', (the channel name without the leading #), and the 'message', (the text of the message).  If the message was posted by a bot, then 'user' will equal :bot.

You can respond to events by sending messages through the slack_connection.  There are two methods for this use:

    slack_connection.send_message(channel, message, username, avatar, avatar_is_emoji)

or:

    slack_connection.send_message_as_user(channel, message)

Here are events that you may wish to listen for:

    on_connected()
    on_close()
    on_message(user, channel)
    on_channel_joined(user, channel)
    on_channel_left(user, channel)

## Directly calling slack methods

If you are going ultra simple and just want to make api calls without establishing a real-time-messaging session, you can use the slack methods available in `slackbot_frd/lib/slack_methods/` directly.  These are named directly after [web api methods provided by the slack REST API](https://api.slack.com/methods).  For example, here's a regular ruby script that posts to a given channel using the [chat.postMessage](https://api.slack.com/methods/chat.postMessage) method:

    #!/usr/bin/env ruby

    # Can also just `require 'slackbot_frd'` if you want to be lazy
    # and don't care about loading more than you need
    require 'slackbot_frd/lib/slack_methods/chat_post_message'

    ChatPostMessage.postMessage(
        '<dis-be-my-token-sucka>',
        '#fun_room',                  # channel to post to
        'Oh, ah, ah, ah, ah',         # Text to post
        'Down With The Sickness Bot', # Name of your bot
        ':devil:'                     # emoji to use as your bot's avatar
    )

This simple method can give you a lot of power.  For instance, I use this at work to post reminders for daily standups.  I just call the script from a [cron](http://en.wikipedia.org/wiki/Cron) job.

## Cool Tricks

### Posting as a bot using your regular user token

You can post a chat message that appears to come from a "bot," using only your user's API token!  Don't be stupid though.  If you do something irresponsible it can easily be tracked back to you.

* From inside a "slack_connection" (such as the one passed to your `SlackbotFrd::Bot` subclass):

    ```
    slack_connection.send_message(
        channel,
        message,
        username_to_show,
        avatar_emoji_or_url,
        true_if_avatar_is_emoji
    )
    ```

* Directly using `ChatPostMessage`:

    ```
    ChatPostMessage.postMessage(
        channel,
        message,
        username_to_show,
        avatar_emoji_or_url,
        true_if_avatar_is_emoji
    )
    ```

## How do I set up incoming webhooks with this?

That's coming later.  Soon this will be usable as a rails engine which gives you full active record and a router.  Why rails?  Cause that's what I use.

## Bugs, Features, and Contributions

This is a very young and incomplete project. Please open bugs and send pull requests!
