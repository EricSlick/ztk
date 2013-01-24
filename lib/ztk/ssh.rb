################################################################################
#
#      Author: Zachary Patten <zachary@jovelabs.net>
#   Copyright: Copyright (c) Jove Labs
#     License: Apache License, Version 2.0
#
#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#   limitations under the License.
#
################################################################################

require "ostruct"
require "net/ssh"
require "net/ssh/proxy/command"
require "net/sftp"

module ZTK

  # ZTK::SSH Error Class
  #
  # @author Zachary Patten <zachary@jovelabs.net>
  class SSHError < Error; end

  # SSH Multi-function Class
  #
  # We can get a new instance of SSH like so:
  #
  #     ssh = ZTK::SSH.new
  #
  # If we wanted to redirect STDOUT and STDERR to a StringIO we can do this:
  #
  #     std_combo = StringIO.new
  #     ssh = ZTK::SSH.new(:stdout => std_combo, :stderr => std_combo)
  #
  # If you want to specify SSH options you can:
  #
  #     keys = File.expand_path(File.join(ENV['HOME'], '.ssh', 'id_rsa'))
  #     ssh = ZTK::SSH.new(:host_name => '127.0.0.1', :user => ENV['USER'], :keys => keys)
  #
  # = Configuration Examples:
  #
  # To proxy through another host, for example SSH to 192.168.1.1 through 192.168.0.1:
  #
  #     ssh.config do |config|
  #       config.user = ENV['USER']
  #       config.host_name = '192.168.1.1'
  #       config.proxy_user = ENV['USER']
  #       config.proxy_host_name = '192.168.0.1'
  #     end
  #
  # Specify an identity file:
  #
  #     ssh.config do |config|
  #       config.keys = File.expand_path(File.join(ENV['HOME'], '.ssh', 'id_rsa'))
  #       config.proxy_keys = File.expand_path(File.join(ENV['HOME'], '.ssh', 'id_rsa'))
  #     end
  #
  # Specify a timeout:
  #
  #     ssh.config do |config|
  #       config.timeout = 30
  #     end
  #
  # Specify a password:
  #
  #     ssh.config do |config|
  #       config.password = 'p@$$w0rd'
  #     end
  #
  # Check host keys, the default is false (off):
  #
  #     ssh.config do |config|
  #       config.host_key_verify = true
  #     end
  #
  # @author Zachary Patten <zachary@jovelabs.net>
  class SSH < ZTK::Base

    # @param [Hash] config Configuration options hash.
    # @option config [String] :host_name Server hostname to connect to.
    # @option config [String] :user Username to use for authentication.
    # @option config [String, Array<String>] :keys A single or series of
    #   identity files to use for authentication.
    # @option config [String] :password Password to use for authentication.
    # @option config [Integer] :timeout SSH connection timeout to use.
    # @option config [Boolean] :compression Weither or not to use compression
    #   for this session.
    # @option config [Integer] :compression_level What level of compression to
    #   use.
    # @option config [String] :proxy_host_name Server hostname to proxy through.
    # @option config [String] :proxy_user Username to use for proxy
    #   authentication.
    # @option config [String, Array<String>] :proxy_keys A single or series of
    #   identity files to use for authentication with the proxy.
    def initialize(config={})
      super({
        :forward_agent => true,
        :compression => false,
        :user_known_hosts_file => '/dev/null'
        :timeout => 60
      }.merge(config))
    end

    def inspect
      tags = Array.new

      if @config.proxy_host_name
        proxy_user_host = "#{@config.proxy_user}@#{@config.proxy_host_name}"
        proxy_port = (@config.proxy_port ? ":#{@config.proxy_port}" : nil)
        tags << [proxy_user_host, proxy_port].compact.join
        tags << " >>> "
      end

      user_host = "#{@config.user}@#{@config.host_name}"
      port = (@config.port ? ":#{@config.port}" : nil)
      tags << [user_host, port].compact.join

      tags.join.strip
    end

    # Starts an SSH session.  Can also be used to get the Net::SSH object.
    #
    # Primarily used internally.
    def ssh
      @ssh ||= Net::SSH.start(@config.host_name, @config.user, ssh_options)
    end

    # Starts an SFTP session.  Can also be used to get the Net::SSH object.
    #
    # Primarily used internally.
    def sftp
      @sftp ||= Net::SFTP.start(@config.host_name, @config.user, ssh_options)
    end

    # Close our session gracefully.
    def close
      config.logger.debug { "close" }
      ssh and !ssh.closed? and ssh.close
    end

    # Launches an SSH console, replacing the current process with the console
    # process.
    #
    # @example Launch a console:
    #   $logger = ZTK::Logger.new(STDOUT)
    #   ssh = ZTK::SSH.new
    #   ssh.config do |config|
    #     config.user = ENV["USER"]
    #     config.host_name = "127.0.0.1"
    #   end
    #   ssh.console
    def console
      config.logger.info { "console(#{console_command.inspect})" }
      config.logger.debug { "config(#{@config.inspect})" }

      Kernel.exec(console_command)
    end

    # Executes a command on the remote host.
    #
    # @param [String] command The command to execute.
    # @param [Hash] options The options hash for executing the command.
    # @option options [Boolean] :silence Squelch output to STDOUT and STDERR.
    #   If the log level is :debug, STDOUT and STDERR will go to the log file
    #   regardless of this setting.  STDOUT and STDERR are always returned in
    #   the output return value regardless of this setting.
    #
    # @return [OpenStruct#output] The output of the command, both STDOUT and
    #   STDERR.
    # @return [OpenStruct#exit] The exit status (i.e. $?).
    #
    # @example Execute a command:
    #
    #   ssh = ZTK::SSH.new
    #   ssh.config do |config|
    #     config.user = ENV["USER"]
    #     config.host_name = "127.0.0.1"
    #   end
    #   puts ssh.exec("hostname -f").inspect
    def exec(command, options={})

      def log_header(tag)
        count = 8
        sep = ("=" * count)
        header = [sep, "[ #{tag} ]", sep, "[ #{self.inspect} ]", sep, "[ #{tag} ]", sep].join
        "#{header}\n"
      end

      config.logger.debug { "config(#{@config.inspect})" }
      config.logger.info { "exec(#{command.inspect}, #{options.inspect})" }

      options = OpenStruct.new({ :silence => false }.merge(options))
      config.logger.debug { "options(#{options.inspect})" }

      output = ""
      stdout_header = false
      stderr_header = false

      ZTK::RescueRetry.try(:tries => 3, :on => EOFError) do
        @ssh = Net::SSH.start(@config.host_name, @config.user, ssh_options)

        channel = ssh.open_channel do |chan|
          config.logger.debug { "Channel opened." }

          direct_log(:debug) { log_header("COMMAND") }
          direct_log(:debug) { "#{command}\n" }
          direct_log(:debug) { log_header("OPENED") }

          chan.exec(command) do |ch, success|
            raise SSHError, "Could not execute '#{command}'." unless success

            ch.on_data do |c, data|
              if !stdout_header
                direct_log(:debug) { log_header("STDOUT") }
                stdout_header = true
                stderr_header = false
              end
              direct_log(:debug) { data }

              @config.stdout.print(data) unless options.silence
              output += data
            end

            ch.on_extended_data do |c, type, data|
              if !stderr_header
                direct_log(:warn) { log_header("STDERR") }
                stderr_header = true
                stdout_header = false
              end
              direct_log(:warn) { data }

              @config.stderr.print(data) unless options.silence
              output += data
            end

            ch.on_open_failed do |c, code, desc|
              config.logger.fatal { "Open failed! (#{code.inspect} - #{desc.inspect})" }
            end

          end
        end
        channel.wait

        direct_log(:debug) { log_header("CLOSED") }
        config.logger.debug { "Channel closed." }
      end

      OpenStruct.new(:output => output, :exit => $?)
    end

    # Uploads a local file to a remote host.
    #
    # @param [String] local The local file/path you wish to upload from.
    # @param [String] remote The remote file/path you with to upload to.
    #
    # @example Upload a file:
    #   $logger = ZTK::Logger.new(STDOUT)
    #   ssh = ZTK::SSH.new
    #   ssh.config do |config|
    #     config.user = ENV["USER"]
    #     config.host_name = "127.0.0.1"
    #   end
    #   local = File.expand_path(File.join(ENV["HOME"], ".ssh", "id_rsa.pub"))
    #   remote = File.expand_path(File.join("/tmp", "id_rsa.pub"))
    #   ssh.upload(local, remote)
    def upload(local, remote)
      config.logger.debug { "config(#{@config.inspect})" }
      config.logger.info { "upload(#{local.inspect}, #{remote.inspect})" }

      ZTK::RescueRetry.try(:tries => 3, :on => EOFError) do
        @sftp = Net::SFTP.start(@config.host_name, @config.user, ssh_options)
        sftp.upload!(local.to_s, remote.to_s) do |event, uploader, *args|
          case event
          when :open
            config.logger.debug { "upload(#{args[0].local} -> #{args[0].remote})" }
          when :close
            config.logger.debug { "close(#{args[0].remote})" }
          when :mkdir
            config.logger.debug { "mkdir(#{args[0]})" }
          when :put
            config.logger.debug { "put(#{args[0].remote}, size #{args[2].size} bytes, offset #{args[1]})" }
          when :finish
            config.logger.debug { "finish" }
          end
        end
      end

      true
    end

    # Downloads a remote file to the local host.
    #
    # @param [String] remote The remote file/path you with to download from.
    # @param [String] local The local file/path you wish to download to.
    #
    # @example Download a file:
    #   $logger = ZTK::Logger.new(STDOUT)
    #   ssh = ZTK::SSH.new
    #   ssh.config do |config|
    #     config.user = ENV["USER"]
    #     config.host_name = "127.0.0.1"
    #   end
    #   local = File.expand_path(File.join("/tmp", "id_rsa.pub"))
    #   remote = File.expand_path(File.join(ENV["HOME"], ".ssh", "id_rsa.pub"))
    #   ssh.download(remote, local)
    def download(remote, local)
      config.logger.debug { "config(#{@config.inspect})" }
      config.logger.info { "download(#{remote.inspect}, #{local.inspect})" }

      ZTK::RescueRetry.try(:tries => 3, :on => EOFError) do
        @sftp = Net::SFTP.start(@config.host_name, @config.user, ssh_options)
        sftp.download!(remote.to_s, local.to_s) do |event, downloader, *args|
          case event
          when :open
            config.logger.debug { "download(#{args[0].remote} -> #{args[0].local})" }
          when :close
            config.logger.debug { "close(#{args[0].local})" }
          when :mkdir
            config.logger.debug { "mkdir(#{args[0]})" }
          when :get
            config.logger.debug { "get(#{args[0].remote}, size #{args[2].size} bytes, offset #{args[1]})" }
          when :finish
            config.logger.debug { "finish" }
          end
        end
      end

      true
    end


  private

    # Builds our SSH console command.
    def console_command
      command = [ "ssh" ]
      command << [ "-q" ]
      command << [ "-A" ]
      command << [ "-o", "UserKnownHostsFile=/dev/null" ]
      command << [ "-o", "StrictHostKeyChecking=no" ]
      command << [ "-o", "KeepAlive=yes" ]
      command << [ "-o", "ServerAliveInterval=60" ]
      command << [ "-i", @config.keys ] if @config.keys
      command << [ "-p", @config.port ] if @config.port
      command << [ "-o", "ProxyCommand=\"#{proxy_command}\"" ] if @config.proxy_host_name
      command << "#{@config.user}@#{@config.host_name}"
      command = command.flatten.compact.join(" ")
      config.logger.debug { "console_command(#{command.inspect})" }
      command
    end

    # Builds our SSH proxy command.
    def proxy_command
      if !@config.proxy_user
        message = "You must specify an proxy user in order to SSH proxy."
        config.logger.fatal { message }
        raise SSHError, message
      end

      if !@config.proxy_host_name
        message = "You must specify an proxy host_name in order to SSH proxy."
        config.logger.fatal { message }
        raise SSHError, message
      end

      command = ["ssh"]
      command << [ "-q" ]
      command << [ "-A" ]
      command << [ "-o", "UserKnownHostsFile=/dev/null" ]
      command << [ "-o", "StrictHostKeyChecking=no" ]
      command << [ "-o", "KeepAlive=yes" ]
      command << [ "-o", "ServerAliveInterval=60" ]
      command << [ "-i", @config.proxy_keys ] if @config.proxy_keys
      command << [ "-p", @config.proxy_port ] if @config.proxy_port
      command << "#{@config.proxy_user}@#{@config.proxy_host_name}"
      command << "nc %h %p"
      command = command.flatten.compact.join(" ")
      config.logger.debug { "proxy_command(#{command.inspect})" }
      command
    end

    # Builds our SSH options hash.
    def ssh_options
      options = {}

      # These are plainly documented on the Net::SSH config class.
      options.merge!(:encryption => @config.encryption) if @config.encryption
      options.merge!(:compression => @config.compression) if @config.compression
      options.merge!(:compression_level => @config.compression_level) if @config.compression_level
      options.merge!(:timeout => @config.timeout) if @config.timeout
      options.merge!(:forward_agent => @config.forward_agent) if @config.forward_agent
      options.merge!(:global_known_hosts_file => @config.global_known_hosts_file) if @config.global_known_hosts_file
      options.merge!(:auth_methods => @config.auth_methods) if @config.auth_methods
      options.merge!(:host_key => @config.host_key) if @config.host_key
      options.merge!(:host_key_alias => @config.host_key_alias) if @config.host_key_alias
      options.merge!(:host_name => @config.host_name) if @config.host_name
      options.merge!(:keys => @config.keys) if @config.keys
      options.merge!(:keys_only => @config.keys_only) if @config.keys_only
      options.merge!(:hmac => @config.hmac) if @config.hmac
      options.merge!(:port => @config.port) if @config.port
      options.merge!(:proxy => Net::SSH::Proxy::Command.new(proxy_command)) if @config.proxy_host_name
      options.merge!(:rekey_limit => @config.rekey_limit) if @config.rekey_limit
      options.merge!(:user => @config.user) if @config.user
      options.merge!(:user_known_hosts_file => @config.user_known_hosts_file) if @config.user_known_hosts_file

      # This is not plainly documented on the Net::SSH config class.
      options.merge!(:password => @config.password) if @config.password

      config.logger.debug { "ssh_options(#{options.inspect})" }
      options
    end

  end

end
