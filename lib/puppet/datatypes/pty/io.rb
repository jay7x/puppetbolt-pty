# frozen_string_literal: true

# The PTY::IO object represents an IO-object to communicate via the PTY. This
# object is created by the `pty::spawn()` function and passed to the block
# yielded. It's not expected to be created manually.
#
# @method write(msg)
#   Send a message as-is
# @method puts(msg)
#   Send a message with terminating line feed appended
# @method read(opts)
#   Read the input if any
# @method set_expected_prompt(prompt)
#   Set the prompt to implicitly expect by `pwp()` and `pwp_until()` methods
# @method expect(pattern, opts)
#   Wait for a pattern to appear (or until timeout expires)
# @method pwp(msg, opts)
#   Send a message, wait for the prompt and return the text received
# @method pwp_until(msg, prompt, opts)
#   Send the message, wait for the prompt, check for the pattern, repeat if not found
# @method type_in(msg, opts)
#   Send a message by typing a char and waiting for it to be echoed back by console before typing a next one
# @method set_raw
#   Switch the pty to raw mode
# @method set_cooked
#   Switch the pty to 'cooked' mode (default mode usually)
# @method set_echo(echo)
#   Enable/disable echo on the pty
# @method set_debug(debug)
#   Enable/disable debug messages on stderr
Puppet::DataTypes.create_type(:'PTY::IO') do
  interface <<-PUPPET
    attributes => {},
    functions => {
      write => Callable[[String[1]], Integer],
      puts => Callable[[String], Undef],
      read => Callable[[
        Struct[{
          maxlen => Optional[Integer[0]],
          timeout => Optional[Variant[Integer[0], Float]]
        }],
        0, 1], Variant[String, Undef]
      ],
      set_expected_prompt => Callable[[Variant[Regexp, String]], Regexp],
      expect => Callable[[
        Variant[Regexp, String[1]],
        Struct[{
          timeout => Optional[Variant[Integer, Float]]
        }],
        1, 2], Variant[String, Undef]
      ],
      pwp => Callable[[
        String[1],
        Struct[{
          timeout => Optional[Variant[Integer, Float]],
          keep_prompt => Optional[Boolean],
        }],
        1, 2], Variant[String, Undef]
      ],
      pwp_until => Callable[[
        String[1],
        Regexp,
        Struct[{
          interval => Optional[Variant[Integer[0], FLoat]],
          limit => Optional[Integer[0]],
          timeout => Optional[Variant[Integer[0], Float]]
        }],
        2, 3], Variant[String, Undef]
      ],
      type_in => Callable[[String[1]], Variant[String, Undef]],
      set_raw => Callable[[], Undef],
      set_cooked => Callable[[], Undef],
      set_echo => Callable[[Boolean], Boolean],
      set_debug => Callable[[Boolean], Boolean],
    }
  PUPPET

  load_file('puppet_x/pty/io')

  PuppetX::PTY::IO.include(Puppet::Pops::Types::PuppetObject)
  implementation_class PuppetX::PTY::IO
end
