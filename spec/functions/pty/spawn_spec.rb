# frozen_string_literal: true

require 'spec_helper'
require 'bolt_spec/bolt_context'
require 'pty'
require_relative '../../../lib/puppet_x/pty/io'

describe 'pty::spawn' do
  let(:pty_io) { PuppetX::PTY::IO.new }
  let(:command) { ['/nonexistent', '1', '2', '3'] }
  let(:input) { instance_double(StringIO) }
  let(:output) { instance_double(StringIO) }
  let(:pid) { 123_456 }

  include BoltSpec::BoltContext
  # This function should always be tested in the Bolt context
  around(:each) do |example|
    in_bolt_context do
      example.run
    end
  end

  context 'in non-block form' do
    it 'runs successfully' do
      expect(PuppetX::PTY::IO).to receive(:new).and_return(pty_io)
      expect(PTY).to receive(:spawn).with(*command).and_return([input, output, pid])
      is_expected.to run.with_params(command).and_return(pty_io)
    end
  end
end
