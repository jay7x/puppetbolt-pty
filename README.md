# `pty` Puppet Bolt module

## Table of Contents

1. [Description](#description)
1. [Usage](#usage)
1. [Reference](#reference)

## Description

The module provides resources to spawn a command on a PTY and to interact with it from Puppet DSL.

## Usage

Use `pty::spawn()` function in a Bolt plan to spawn a command and yield a code block with a PTY::IO datatype parameter to interact with the process spawned.

### Example 1. Talk to /bin/sh locally

```puppet
  pty::spawn(['/bin/sh', '--norc']) |$pty| {
    # Enable debug messages on stderr
    $pty.set_debug(true)
    # Switch PTY to raw mode
    $pty.set_raw()

    # Change PS1 prompt to something we know
    $pty.puts('export PS1="pty::io$ "')
    # Read reply and throw it away (wait 0.5 second for more input if any)
    $pty.read(timeout => 0.5)

    # Set the prompt to be expected by `pwp()` and `pwp_until()` methods
    $pty.set_expected_prompt(/\Rpty::io\$ /)

    # Send `hostname` command, get reply and strip any whitespace including terminating '\n'
    $hostname = $pty.pwp('hostname').strip()
    out::verbose($hostname)

    # Type '# Hello world'
    out::verbose($pty.type_in('# Hello world'))

    # Print current unix time and check if last digit is 0. Repeat 11 times if
    not, waiting 1 sec before next iteration. Return unix time matching.
    $time = $pty.pwp_until('date +"%s"', /0$/, { interval => 1, limit => 11 }).strip()
    out::verbose($time)
  }
```

### Example 2. Configure remote iDRAC via SSH

**WARNING:** Do not execute this code in your environment until you clearly
understand what it does. The module authors takes no responsibility for any
damage, loss, or injury resulting from the use or inability to use this example
code. By using this example code, you acknowledge that you do so at your own
risk!

```puppet
  $targets.get_targets.parallelize |$t| {
    pty::spawn(['/usr/bin/ssh', $t.vars.get('bmc_host')]) |$bmc| {
      $bmc.set_raw()
      $bmc.expect(/^(\/[^>]+>|racadm>>)/, timeout => 60) # Wait for prompt
      $bmc.set_expected_prompt(/\Rracadm>>/)
      $bmc.pwp('racadm') # Not needed on newer iDRAC but does no real harm

      $bmc.pwp('set iDRAC.VirtualConsole.PluginType HTML5')            # Use HTML5 VirtualConsole
      # BIOS setup
      $bmc.pwp('set BIOS.ProcSettings.LogicalProc Disabled')           # Disable HyperThreading
      $bmc.pwp('set BIOS.SysProfileSettings.SysProfile PerfOptimized') # Use PerfOptimized system profile

      # Create job to setup BIOS on reboot
      $bios_setup_jid = $bmc.pwp('jobqueue create BIOS.Setup.1-1') ? {
        /^Commit JID = JID_(\d+)$/ => "JID_${1}",
        default => fail('Cannot create BIOS.Setup.1-1 job'),
      }

      if $reboot {
        $bmc.pwp('serveraction powercycle')

        # Check the job status until regex matches or timeout happens.
        # Do 20 tries, sleeping 15 sec before next try.
        $bmc.pwp_until("jobqueue view -i ${bios_setup_jid}", /^Message=\[PR19:/, interval => 15, limit => 20).lest || {
          fail("Job ${bios_setup_jid} doesn't succeed in time")
        }
      }
    }
  }
```

## Reference

For detailed information on functions and types, see [REFERENCE.md](https://github.com/jay7x/puppet-pty/blob/main/REFERENCE.md).

## License

See the LICENSE file in this repository for terms and conditions.
