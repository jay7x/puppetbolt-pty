# frozen_string_literal: true

require 'pty'
require 'puppet_x/pty/io'

# @summary Spawns the specified command on a newly allocated pty.
# This function is designed to be used in a Bolt plan. See PTY::IO
# DataType documentation for more details.
#
# **Note:** Not available in apply block.
#
Puppet::Functions.create_function(:'pty::spawn') do
  # @param cmd The command to spawn
  # @param block The code block, that is using PTY::IO object yielded to talk to the command executed
  # @yield The code block to talk to the command spawned
  # @yieldparam The PTY::IO object
  #
  # @example Spawn /bin/sh and get the hostname
  #   pty::spawn(['/bin/sh', '--norc']) |$pty| {
  #     $pty.puts('export PS1="pty::io$ "')
  #     $pty.read()
  #     $pty.set_expected_prompt(/\Rpty::io\$ /)
  #     $hostname = $pty.pwp('hostname').strip()
  #   }

  dispatch :spawn do
    param 'Array[String[1]]', :cmd
    block_param 'Callable[PTY::IO]', :block
    return_type 'Undef'
  end

  def spawn(cmd)
    # Ensure this function is not called in apply block
    unless Puppet[:tasks]
      raise Puppet::ParseErrorWithIssue
        .from_issue_and_stack(Bolt::PAL::Issues::PLAN_OPERATION_NOT_SUPPORTED_WHEN_COMPILING, action: 'pty::spawn')
    end

    PTY.spawn(*cmd) do |input, output, _pid|
      pty_io = PuppetX::PTY::IO.new
      pty_io.set_streams(input, output)
      yield pty_io
    end
    nil
  end
end
