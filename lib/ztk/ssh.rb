################################################################################
#
#      Author: Zachary Patten <zachary@jovelabs.com>
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

  # ZTK::SSH base error class
  class SSHError < Error; end

  # We can get a new instance of SSH like so:
  #     ssh = ZTK::SSH.new
  #
  # If we wanted to redirect STDOUT and STDERR to a StringIO we can do this:
  #     std_combo = StringIO.new
  #     ssh = ZTK::SSH.new(:stdout => std_combo, :stderr => std_combo)
  #
  # If you want to specify SSH options you can:
  #     identify_file = File.expand_path(File.join(ENV['HOME'], '.ssh', 'id_rsa'))
  #     ssh = ZTK::SSH.new(:host => '127.0.0.1', :user => ENV['USER'], :identify_file => identify_file)
  #
  # = Configuration Examples:
  #
  # To proxy through another host, for example SSH to 192.168.1.1 through 192.168.0.1:
  #     ssh.config do |config|
  #       config.user = ENV['USER']
  #       config.host = '192.168.1.1'
  #       config.proxy_user = ENV['USER']
  #       config.proxy_host = '192.168.0.1'
  #     end
  #
  # Specify an identity file:
  #     ssh.config do |config|
  #       config.identify_file = File.expand_path(File.join(ENV['HOME'], '.ssh', 'id_rsa'))
  #       config.proxy_identify_file = File.expand_path(File.join(ENV['HOME'], '.ssh', 'id_rsa'))
  #     end
  #
  # Specify a timeout:
  #     ssh.config do |config|
  #       config.timeout = 30
  #     end
  #
  # Specify a password:
  #     ssh.config do |config|
  #       config.password = 'p@$$w0rd'
  #     end
  #
  # Check host keys, the default is false (off):
  #     ssh.config do |config|
  #       config.host_key_verify = true
  #     end
  class SSH < ZTK::Base

    # @param [Hash] config configuration options hash
    # @option config [String] :host server hostname to connect to
    # @option config [String] :user username to use for authentication
    # @option config [String] :password password to use for authentication
    # @option config [Integer] :timeout SSH connection timeout to use
    # @option config [String, Array<String>] :identity_file a single or series of identity files to use for authentication
    # @option config [String] :proxy_host server hostname to proxy through
    # @option config [String] :proxy_user username to use for proxy authentication
    # @option config [String] :proxy_identity_file a single identity file to use for authentication with the proxy
    def initialize(config={})
      super(config)
    end

    # Launches an SSH console.
    #
    # @example Upload A File:
    #   $logger = ZTK::Logger.new(STDOUT)
    #   ssh = ZTK::SSH.new
    #   ssh.config do |config|
    #     config.user = ENV["USER"]
    #     config.host = "127.0.0.1"
    #   end
    #   ssh.console
    def console
      log(:debug) { "config(#{@config.inspect})" }

      command = [ "ssh" ]
      command << [ "-q" ]
      command << [ "-o", "UserKnownHostsFile=/dev/null" ]
      command << [ "-o", "StrictHostKeyChecking=no" ]
      command << [ "-o", "KeepAlive=yes" ]
      command << [ "-o", "ServerAliveInterval=60" ]
      command << [ "-i", @config.identity_file ] if @config.identity_file
      command << [ "-o", "ProxyCommand=\"#{proxy_command}\"" ] if @config.proxy_host
      command << "#{@config.user}@#{@config.host}"
      command = command.flatten.compact.join(" ")
      log(:info) { "command(#{command.inspect})" }
      Kernel.exec(command)
    end

    # Executes a command on the remote host.
    #
    # @param [String] command The command to execute.
    # @param [Hash] options The options hash for executing the command.
    # @option options [Boolean] :silence Squelch output to STDOUT and STDERR.  If the log level is :debug, STDOUT and STDERR will go to the log file regardless of this setting.  STDOUT and STDERR are always returned in the output return value regardless of this setting.
    #
    # @return [OpenStruct#output] The output of the command, both STDOUT and STDERR.
    # @return [OpenStruct#exit] The exit status (i.e. $?).
    #
    # @example Execute a command:
    #   $logger = ZTK::Logger.new(STDOUT)
    #   ssh = ZTK::SSH.new
    #   ssh.config do |config|
    #     config.user = ENV["USER"]
    #     config.host = "127.0.0.1"
    #   end
    #   puts ssh.exec("hostname -f").output
    def exec(command, options={})
      log(:debug) { "exec(#{command.inspect}, #{options.inspect})" }
      log(:debug) { "config(#{@config.inspect})" }

      @ssh ||= Net::SSH.start(@config.host, @config.user, ssh_options)
      log(:debug) { "ssh(#{@ssh.inspect})" }

      options = OpenStruct.new({ :silence => false }.merge(options))
      log(:debug) { "options(#{options.inspect})" }

      output = ""
      channel = @ssh.open_channel do |chan|
        log(:debug) { "channel opened" }
        chan.exec(command) do |ch, success|
          raise SSHError, "Could not execute '#{command}'." unless success

          ch.on_data do |c, data|
            log(:debug) { data.chomp.strip }
            @config.stdout.print(data) unless options.silence
            output += data.chomp.strip
          end

          ch.on_extended_data do |c, type, data|
            log(:debug) { data.chomp.strip }
            @config.stderr.print(data) unless options.silence
            output += data.chomp.strip
          end

        end
      end
      channel.wait
      log(:debug) { "channel closed" }

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
    #     config.host = "127.0.0.1"
    #   end
    #   local = File.expand_path(File.join(ENV["HOME"], ".ssh", "id_rsa.pub"))
    #   remote = File.expand_path(File.join("/tmp", "id_rsa.pub"))
    #   ssh.upload(local, remote)
    def upload(local, remote)
      log(:debug) { "upload(#{local.inspect}, #{remote.inspect})" }
      log(:debug) { "config(#{@config.inspect})" }

      @sftp ||= Net::SFTP.start(@config.host, @config.user, ssh_options)
      log(:debug) { "sftp(#{@sftp.inspect})" }

      @sftp.upload!(local.to_s, remote.to_s) do |event, uploader, *args|
        case event
        when :open
          log(:info) { "upload(#{args[0].local} -> #{args[0].remote})" }
        when :close
          log(:debug) { "close(#{args[0].remote})" }
        when :mkdir
          log(:debug) { "mkdir(#{args[0]})" }
        when :put
          log(:debug) { "put(#{args[0].remote}, size #{args[2].size} bytes, offset #{args[1]})" }
        when :finish
          log(:info) { "finish" }
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
    #     config.host = "127.0.0.1"
    #   end
    #   local = File.expand_path(File.join("/tmp", "id_rsa.pub"))
    #   remote = File.expand_path(File.join(ENV["HOME"], ".ssh", "id_rsa.pub"))
    #   ssh.download(remote, local)
    def download(remote, local)
      log(:debug) { "download(#{remote.inspect}, #{local.inspect})" }
      log(:debug) { "config(#{@config.inspect})" }

      @sftp ||= Net::SFTP.start(@config.host, @config.user, ssh_options)
      log(:debug) { "sftp(#{@sftp.inspect})" }

      @sftp.download!(remote.to_s, local.to_s) do |event, downloader, *args|
        case event
        when :open
          log(:info) { "download(#{args[0].remote} -> #{args[0].local})" }
        when :close
          log(:debug) { "close(#{args[0].local})" }
        when :mkdir
          log(:debug) { "mkdir(#{args[0]})" }
        when :get
          log(:debug) { "get(#{args[0].remote}, size #{args[2].size} bytes, offset #{args[1]})" }
        when :finish
          log(:info) { "finish" }
        end
      end

      true
    end


  private

    def proxy_command
      log(:debug) { "proxy_command" }
      log(:debug) { "config(#{@config.inspect})" }

      if !@config.identity_file
        message = "You must specify an identity file in order to SSH proxy."
        log(:fatal) { message }
        raise SSHError, message
      end

      command = ["ssh"]
      command << [ "-q" ]
      command << [ "-o", "UserKnownHostsFile=/dev/null" ]
      command << [ "-o", "StrictHostKeyChecking=no" ]
      command << [ "-o", "KeepAlive=yes" ]
      command << [ "-o", "ServerAliveInterval=60" ]
      command << [ "-i", @config.proxy_identity_file ] if @config.proxy_identity_file
      command << "#{@config.proxy_user}@#{@config.proxy_host}"
      command << "nc %h %p"
      command = command.flatten.compact.join(" ")
      log(:debug) { "proxy_command(#{command.inspect})" }
      command
    end

    def ssh_options
      log(:debug) { "ssh_options" }
      log(:debug) { "config(#{@config.inspect})" }

      options = {}
      options.merge!(:password => @config.password) if @config.password
      options.merge!(:keys => @config.identity_file) if @config.identity_file
      options.merge!(:timeout => @config.timeout) if @config.timeout
      options.merge!(:user_known_hosts_file  => '/dev/null') if !@config.host_key_verify
      options.merge!(:proxy => Net::SSH::Proxy::Command.new(proxy_command)) if @config.proxy_host
      log(:debug) { "ssh_options(#{options.inspect})" }
      options
    end

  end

end
