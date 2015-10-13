require 'logger'
require 'fileutils'

# This logger is meant to be used in multithreading environment.
#
# It holds only one file handle opened in one background thread and uses queue to write all messages consecutively and safely
#
# Usage is almost the same as for regular Logger:
#   logger = BackgroundLogger.new "mylog.log"
#   logger.info "hello world"
#   Thread.new{ logger.error "error from thread" }
#
# if suffix is given then "_<date/time>.log" is appended, depending on suffix. can be :monthly, :daily, or :hourly
#
# You can pass custom formatter, proc with same arguments as for Logger#formatter=.
# Currently you can't change date format for formatter
# NOTE: Since logger file is opened and is held withing thread, GC won't close it when BackgroundLogger object gets out of scope.
#       Please make sure to close it manually, or find better solution and fix this code :)
class BackgroundLogger
  TIME_SUFFIX_FORMATS = {
    monthly: '%Y%m',
    daily: '%Y%m%d',
    hourly: '%Y%m%d%H'
  }

  def initialize(path, suffix=nil, formatter: nil)
    raise TypeError, "path must be String" if !path.is_a?(String)
    path = "#{path.gsub(/\.log$/i, '')}_#{Time.now.strftime(TIME_SUFFIX_FORMATS[suffix])}.log" if suffix
    run path, formatter
  end

  def log(*args)
    @queue << args
  end

  def close
    @thread.kill
  end

  LEVELS = {
    :debug => Logger::DEBUG,
    :info => Logger::INFO,
    :warn => Logger::WARN,
    :error => Logger::ERROR,
    :fatal => Logger::FATAL,
    :unknown => Logger::UNKNOWN,
  }

  LEVELS.each do |name, level|
    define_method name do |message|
      log level, message
    end
  end

  alias add log

  private
  def run(path, formatter)
    folder = path.gsub(/[^\/]+$/, '')[0..-2]
    FileUtils.mkdir_p(folder) if !folder.empty?
    Logger.new(path).close #test opening in main thread

    @queue = Queue.new
    @thread = Thread.new do
      begin
        pid = Process.pid
        logger = Logger.new path
        logger.datetime_format = Time.now.strftime "%Y-%m-%dT%H:%M:%S"
        logger.formatter = formatter || proc do |severity, datetime, progname, msg|
          "#{pid}: #{datetime} #{severity}: #{msg}\n"
        end

        loop{ logger.log(*@queue.pop) }
      ensure
        logger.close if logger
        @queue = nil
      end
    end
  end
end