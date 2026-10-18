require 'rails_helper'

RSpec.describe TokenPrompt do
  let(:output) { StringIO.new }

  around do |example|
    saved = ENV.fetch('SHORTCUT_API_TOKEN', nil)
    example.run
  ensure
    ENV['SHORTCUT_API_TOKEN'] = saved
  end

  def read(input)
    described_class.read('SHORTCUT_API_TOKEN', input: input, output: output)
  end

  context 'with the environment variable set' do
    before { ENV['SHORTCUT_API_TOKEN'] = " from-env\n" }

    it 'takes the token from it, trimmed, and asks for nothing' do
      expect(read(StringIO.new("typed\n"))).to eq('from-env')
      expect(output.string).not_to include('Paste')
    end

    # A variable left exported from an earlier run would otherwise replace a token unannounced
    it 'says the token came from the variable, without printing it' do
      read(StringIO.new)

      expect(output.string).to include('Using SHORTCUT_API_TOKEN from the environment').and exclude('from-env')
    end
  end

  context 'with the environment variable unset' do
    before { ENV.delete('SHORTCUT_API_TOKEN') }

    it 'asks for the token and reads a line from piped input' do
      expect(read(StringIO.new("  piped-token \n"))).to eq('piped-token')
      expect(output.string).to include('Paste the token')
    end

    it 'reads from a terminal with echo off' do
      terminal = instance_double(IO, tty?: true)
      allow(terminal).to receive(:noecho).and_yield(terminal)
      allow(terminal).to receive(:gets).and_return("typed-token\n")

      expect(read(terminal)).to eq('typed-token')
      expect(terminal).to have_received(:noecho)
      expect(output.string).not_to include('typed-token')
    end

    it 'is nil when nothing is entered' do
      expect(read(StringIO.new(''))).to be_nil
    end
  end

  it 'treats a blank variable as unset' do
    ENV['SHORTCUT_API_TOKEN'] = ' '

    expect(read(StringIO.new("typed\n"))).to eq('typed')
  end
end
