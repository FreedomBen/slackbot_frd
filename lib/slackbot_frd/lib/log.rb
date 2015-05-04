require 'colorize'

module SlackbotFrd
  class Log
    @levels = {verbose: 1, debug: 2, info: 3, warn: 4, error: 5}
    @default_level = :info

    class << self
      attr_writer :level
      attr_accessor :logfile
    end

    def self.level
      return @default_level unless @level
      @level
    end

    def self.level_on(level)
      @levels[level] >= @levels[self.level]
    end

    def self.colors
      [:green, :red, :yellow, :none, :blue]
    end

    def self.error(message)
      log('Error', message, :red) if level_on(:error)
    end

    def self.warn(message)
      log('Warn', message, :yellow) if level_on(:warn)
    end

    def self.debug(message)
      log('Debug', message, :green) if level_on(:debug)
    end

    def self.info(message)
      log('Info', message, :blue) if level_on(:info)
    end

    def self.verbose(message)
      log('Verbose', message, :magenta) if level_on(:verbose)
    end

    def self.log(loglevel, message, color = :none)
      om = "#{DateTime.now.strftime('%Y-%m-%e %H:%M:%S.%L %z')}: [#{loglevel}]: #{message}\n"
      print om.send(color)
      begin
        raise StandardError.new("No log file specified. (Set with SlackbotFrd::Log.logfile=)") unless @logfile
        File.open(@logfile, 'a') do |f|
          f.write(om)
        end
      rescue StandardError => e
        puts "OH NO!  ERROR WRITING TO LOG FILE!: #{e}"
      end
      om
    end
  end
end
