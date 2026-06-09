# frozen_string_literal: true

require 'pty'
require 'puppet_x/pty/io'

# @summary
#   Spawns the specified command on a newly allocated pty
#
# Spawns the specified command on a newly allocated pty.
#
# **NOTE:** This function is designed to be used in a Bolt plan (not available
# in `apply()` block). See PTY::IO DataType documentation for more details.
#
Puppet::Functions.create_function(:'pty::spawn') do
  # Spawns the specified command on a newly allocated pty (block form).
  #
  # @param cmd
  #   The command to spawn.
  # @param block
  #   The code block, that is using PTY::IO object yielded to talk to the
  #   command executed. The process executed will be SIGTERM-ed and waited on
  #   block exit.
  # @return Block result.
  #
  # @example Spawn /bin/sh and get the hostname
  #   pty::spawn(['/bin/sh', '--norc']) |$pty| {
  #     $pty.puts('export PS1="pty::io$ "')
  #     $pty.read()
  #     $pty.set_expected_prompt(/\Rpty::io\$ /)
  #     $hostname = $pty.pwp('hostname').strip()
  #   }
  #
  dispatch :spawn_with_block do
    param 'Array[String[1]]', :cmd
    block_param 'Callable[PTY::IO]', :block
    return_type 'Any'
  end

  # Spawns the specified command on a newly allocated pty (non-block form).
  #
  # @param cmd
  #   The command to spawn.
  # @return The PTY::IO object.
  #
  # @example Spawn /bin/sh and get the hostname
  #   $pty = pty::spawn(['/bin/sh', '--norc'])
  #   $pty.puts('export PS1="pty::io$ "')
  #   $pty.read()
  #   $pty.set_expected_prompt(/\Rpty::io\$ /)
  #   $hostname = $pty.pwp('hostname').strip()
  #   $pty.close()
  #
  dispatch :spawn do
    param 'Array[String[1]]', :cmd
    return_type 'PTY::IO'
  end

  def spawn_with_block(cmd)
    fail_if_not_in_plan

    pty_io = spawn(cmd)
    yield pty_io
  ensure
    pty_io&.close
  end

  def spawn(cmd)
    fail_if_not_in_plan

    (input, output, pid) = PTY.spawn(*cmd)
    pty_io = PuppetX::PTY::IO.new
    pty_io.private_init(input, output, pid)
  end

  # Ensure the function is not called in an `apply()` block
  def fail_if_not_in_plan
    return if Puppet[:tasks]

    raise Puppet::ParseErrorWithIssue
      .from_issue_and_stack(Bolt::PAL::Issues::PLAN_OPERATION_NOT_SUPPORTED_WHEN_COMPILING, action: 'pty::spawn')
  end
end
