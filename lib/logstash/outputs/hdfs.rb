# encoding: utf-8
require "logstash/namespace"
require "logstash/outputs/base"
require "logstash/errors"

require "java"
require "logstash-output-hdfs_jars"

java_import org.apache.hadoop.conf.Configuration;
java_import org.apache.hadoop.fs.FSDataOutputStream;
java_import org.apache.hadoop.fs.FileSystem;
java_import org.apache.hadoop.fs.Path;

# This output will write events to files on HDFS. You can use fields
# from the event as parts of the filename and/or path.
class LogStash::Outputs::Hdfs < LogStash::Outputs::Base
  FIELD_REF = /%\{[^}]+\}/

  config_name "hdfs"

  attr_reader :failure_path

  # The path to the file to write. Event fields can be used here,
  # like `/var/log/logstash/%{host}/%{application}`
  # One may also utilize the path option for date-based log
  # rotation via the joda time format. This will use the event
  # timestamp.
  # E.g.: `path => "./test-%{+YYYY-MM-dd}.txt"` to create
  # `./test-2013-05-29.txt`
  #
  # If you use an absolute path you cannot start with a dynamic string.
  # E.g: `/%{myfield}/`, `/test-%{myfield}/` are not valid paths
  config :path, :validate => :string, :required => true

  # The format to use when writing events to the file. This value
  # supports any string and can include `%{name}` and other dynamic
  # strings.
  #
  # If this setting is omitted, the full json representation of the
  # event will be written as a single line.
  config :message_format, :validate => :string

  # Url to connect to HDFS
  config :hdfs_url, :validate => :string, :required => true

  # Flush interval (in seconds) for flushing writes to log files.
  config :flush_interval, :validate => :number, :default => 2

  # Gzip the output stream before writing to disk.
  config :gzip, :validate => :boolean, :default => false

  # If the generated path is invalid, the events will be saved
  # into this file and inside the defined path.
  config :filename_failure, :validate => :string, :default => '_filepath_failures'

  # If the a file is deleted, but an event is comming with the need to be stored
  # in such a file, the plugin will created a gain this file. Default => true
  config :create_if_deleted, :validate => :boolean, :default => true

  def register

    workers_not_supported

    @files = {}

    @path = File.expand_path(path)

    if path_with_field_ref?
      @file_root = extract_file_root
    else
      @file_root = File.dirname(path)
    end
    @failure_path = @filename_failure

    @config = Configuration.new
    @config.set("fs.default.name", @hdfs_url);
    @config.set("dfs.support.append", "true");
    @system = FileSystem.get(config)
  end # def register

  def receive(event)
    return unless output?(event)

    file_output_path = generate_filepath(event)

    if path_with_field_ref? && !inside_file_root?(file_output_path)
      @logger.warn("File: the event tried to write outside the files root, writing the event to the failure file",  :event => event, :filename => @failure_path)
      file_output_path = @failure_path
    elsif !@create_if_deleted && deleted?(file_output_path)
      file_output_path = @failure_path
    end

    output = format_message(event)
    write_event(file_output_path, output)
  end # def receive

  def teardown
    @logger.debug("Teardown: closing files")
    @files.each do |path, fd|
      begin
        fd.close
        @logger.debug("Closed file #{path}", :fd => fd)
      rescue Exception => e
        @logger.error("Exception while flushing and closing files.", :exception => e)
      end
    end
    finished
  end

  private

  def inside_file_root?(log_path)
    target_file = File.expand_path(log_path)
    return target_file.start_with?("#{@file_root.to_s}/")
  end

  def write_event(log_path, event)
    @logger.debug("File, writing event to file.", :filename => log_path)
    ous = open(log_path)
    ous.writeUTF(event)
    ous.writeUTF("\n")
  end

  def flush
    @files.each do |_,dos|
      dos.hflush
    end
  end

  def generate_filepath(event)
    event.sprintf(@path)
  end

  def path_with_field_ref?
    path =~ FIELD_REF
  end

  def format_message(event)
    if @message_format
      event.sprintf(@message_format)
    else
      event.to_json
    end
  end

  def extract_file_root
    parts = File.expand_path(path).split(File::SEPARATOR)
    parts.take_while { |part| part !~ FIELD_REF }.join(File::SEPARATOR)
  end

  def cached?(path)
     @files.include?(path) && !@files[path].nil?
  end

  def deleted?(path)
    !@system.exists(new Path(path))
  end

  def open(file)
    return @files[file] if cached?(file)
    path = Path.new(file)
    @system.setReplication(path, 1);
    @files[file] = (@system.exists(path) ? @system.append(path) : @system.create(path, true))
  end

end # class LogStash::Outputs::File

