require 'stringio'
require 'shellwords'

# A single build step that run after the build is complete
class GitArchiverPublisher < Jenkins::Tasks::Publisher

    attr_accessor :output_filename

    display_name "Create Git Archive"

    # Invoked with the form parameters when this extension point
    # is created from a configuration screen.
    def initialize(attrs = {})
      @output_filename = attrs['output_filename']
      @commit = attrs['commit']
    end

    ##
    # Runs before the build begins
    #
    # @param [Jenkins::Model::Build] build the build which will begin
    # @param [Jenkins::Model::Listener] listener the listener for this build.
    def prebuild(build, listener)
      # do any setup that needs to be done before this build runs.
    end

    ##
    # Runs the step over the given build and reports the progress to the listener.
    #
    # @param [Jenkins::Model::Build] build on which to run this step
    # @param [Jenkins::Launcher] launcher the launcher that can run code on the node running this build
    # @param [Jenkins::Model::Listener] listener the listener for this build.
    def perform(build, launcher, listener)
      env = build.native.getEnvironment()

      @output_filename.strip.scan(Regexp.new '(\$\w*)') do |result|
        @output_filename.sub!(result[0], env[result[0].sub(/\$/, '')]) 
      end

      git_archive_dir_path = build.workspace.to_s + "/git-archive"

      begin
        Dir.mkdir git_archive_dir_path
      rescue Errno::EEXIST
        listener.info '"git-archive" directory already exists.'
      end

      git_archive_path = Shellwords.shellescape("#{git_archive_dir_path}/#{@output_filename}")
      git_archive_command = "git archive -o #{git_archive_path} #{@commit}"

      # Set the repo directory and process streams
      opts = Hash.new
      opts[:chdir] ||= build.workspace.realpath
      opts[:out] ||= StringIO.new
      opts[:err] ||= StringIO.new

      if stdin_str = opts.delete(:stdin_str)
        stdin = StringIO.new
        stdin.puts stdin_str
        stdin.rewind
        opts[:in] = stdin
      end

      # Execute the command and save the output
      val = launcher.execute(git_archive_command, opts)
      opts[:out].rewind
      opts[:err].rewind
      result = {:out => opts[:out].read, :err => opts[:err].read, :val => val}

      raise "Unexpected exit code (#{val}): command: #{git_archive_command.inspect}: result: #{result.inspect}" if opts[:raise] && 0 != val

      listener.info "returning results of run: #{result.inspect}"
  end
end
