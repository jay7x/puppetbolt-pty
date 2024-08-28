# frozen_string_literal: true

require 'puppet_x/pty'
require 'io/console'
require 'io/wait'
require 'expect'

# Wrapper class for the pty interaction
# @method write Write a string as is
# @method puts Write a string with line feed appended
class PuppetX::PTY::IO
  def initialize
    @input = nil
    @output = nil
    @prompt = nil
    @debug = false
  end

  # Set the input & output streams. Used by `pty::spawn` function.
  # @api private
  def set_streams(input, output)
    @input = input
    @output = output
  end

  # Enable/disable debug messages on stderr
  # @param debug Enable debug messages if true, disable otherwise
  def set_debug(debug)
    @debug = debug
  end

  # Set the prompt to implicitly expect by `pwp()` and `pwp_until()` methods
  # @param prompt The prompt to expect (as a String or Regexp)
  # @return The prompt as a Regexp object
  def set_expected_prompt(prompt)
    @prompt = Regexp.new(prompt)
  end

  # Switch the pty to raw mode
  def set_raw
    @input.raw!
    @output.raw!
    nil
  end

  # Switch the pty to 'cooked' mode (default mode usually)
  def set_cooked
    @input.cooked!
    @output.cooked!
    nil
  end

  # Enable/disable echo on the pty
  # @param echo Enable echo if true, disable otherwise
  def set_echo(echo)
    @input.echo = echo
    @output.echo = echo
  end

  # Read the input if any
  # @param opts Option hash
  # @option opts timeout How long to wait for more input coming
  # @option opts maxlen How many bytes to read at once
  # @return The text read
  def read(opts = {})
    timeout = opts.fetch('timeout', 2)
    maxlen = opts.fetch('maxlen', 4096)
    buf = ''
    buf += @input.read_nonblock(maxlen) while @input.wait_readable(timeout)
    debug_msg '<|', buf
    buf
  end

  # Send a message as-is
  # @param msg Message to send
  # @return Amount of bytes sent
  def write(msg)
    @output.write(msg)
  end

  # Send a message with terminating line feed appended
  # @param msg Message to send
  # @return Undef
  def puts(msg)
    debug_msg '|>', msg
    @output.puts(msg)
  end

  # Wait for a pattern to appear (or until timeout expires)
  # @param pattern Pattern to look for
  # @param opts Options hash
  # @option opts timeout How long to look for the prompt
  # @return The text received on success
  # @return Undef if no prompt was found
  def expect(pattern, opts = {})
    timeout = opts.fetch('timeout', 10)
    result = @input.expect(Regexp.new(pattern), timeout)
    return nil unless result
    debug_msg '<|', result[0]
    result[0]
  end

  # Send a message, wait for the prompt and return the text received
  # @param msg Message to send
  # @param opts Options hash
  # @option opts timeout How long to look for the prompt (see `expect()` method)
  # @option opts keep_prompt Do not delete prompt from the end of the text received
  # @return The text received on success
  # @return Undef if no prompt was found
  def pwp(msg, opts = {})
    raise 'Set prompt to expect with set_expected_prompt() before calling pwp()' unless @prompt
    keep_prompt = opts.delete('keep_prompt') || false
    puts(msg)
    result = expect(@prompt, opts)
    return nil unless result
    return result if keep_prompt
    result.sub(%r{#{@prompt}\z}, '') # Strip @prompt from the end of the output
  end

  # Send the message, wait for the prompt, check for the pattern, repeat if not found
  # @param msg Message to send
  # @param pattern Pattern to look for in the output
  # @param opts Options hash
  # @option opts limit How many iterations to do
  # @option opts interval Time to sleep between iterations
  # @option opts timeout How long to look for the prompt on every iteration (see `expect()` method)
  # @return The text received on success
  # @return Undef if no prompt nor pattern was found
  def pwp_until(msg, pattern, opts = {})
    limit = opts.delete('limit') || 1
    interval = opts.delete('interval') || 10
    while limit > 0
      debug_msg '..', "pwp_until() ##{limit} attempt(s) left"
      out = pwp(msg, opts)
      return out if out&.match? pattern
      sleep interval
      limit -= 1
    end
    nil
  end

  # Send a message by typing a char and waiting for it to be echoed back by
  # console before typing a next one
  # @param msg Message to type-in on the pty
  # @param opts Options hash (see read() for options supported)
  # @return Original message on success
  # @return Undef if no typed char was echoed back
  def type_in(msg, opts = {})
    read(opts) # Flush input
    msg.chars.each do |c|
      @output.putc c
      loop do
        return nil unless @input.wait_readable(1) # Return Undef if timeout expired and no input here
        i = @input.getc
        break if i == c
      end
    end
    debug_msg '|>', msg
    @output.putc "\n"
    msg
  end

  private

  # Print debug message of a kind on stderr
  # @param kind Message kind (anything actually, but mostly reflex was it received or sent)
  # @param msg Message to print
  def debug_msg(kind, msg)
    $stderr.write kind, ' ', msg.to_s.tr("\e\n\r ", '␛↴↵␣'), "\n" if @debug
  end
end
