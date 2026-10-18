require 'rails_helper'

RSpec.describe TokenPrompt do
  let(:output) { StringIO.new }

  before { allow(ENV).to receive(:fetch).and_call_original }

  it 'takes the token from the environment variable when it is set' do
    allow(ENV).to receive(:fetch).with('SHORTCUT_API_TOKEN', nil).and_return('from-env')

    expect(described_class.read('SHORTCUT_API_TOKEN', input: StringIO.new("typed\n"), output: output)).to eq('from-env')
    expect(output.string).to be_empty
  end

  it 'reads a line from piped input when the variable is unset' do
    allow(ENV).to receive(:fetch).with('SHORTCUT_API_TOKEN', nil).and_return(nil)

    expect(described_class.read('SHORTCUT_API_TOKEN', input: StringIO.new("  piped-token \n"), output: output))
      .to eq('piped-token')
  end

  it 'reads from a terminal with echo off' do
    allow(ENV).to receive(:fetch).with('SHORTCUT_API_TOKEN', nil).and_return('')
    terminal = instance_double(IO, tty?: true)
    allow(terminal).to receive(:noecho).and_yield(terminal)
    allow(terminal).to receive(:gets).and_return("typed-token\n")

    expect(described_class.read('SHORTCUT_API_TOKEN', input: terminal, output: output)).to eq('typed-token')
    expect(terminal).to have_received(:noecho)
    expect(output.string).not_to include('typed-token')
  end

  it 'is nil when nothing is entered' do
    allow(ENV).to receive(:fetch).with('SHORTCUT_API_TOKEN', nil).and_return(nil)

    expect(described_class.read('SHORTCUT_API_TOKEN', input: StringIO.new(''), output: output)).to be_nil
  end
end
