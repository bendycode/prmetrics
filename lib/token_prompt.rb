require 'io/console'

# Reads a secret for a rake task: from its environment variable when that
# is set, otherwise from standard input, with echo off at a terminal. A
# token passed as a task argument would land in shell history and the
# process list, so the tasks take it no other way.
module TokenPrompt
  def self.read(variable, input: $stdin, output: $stdout)
    from_environment = ENV.fetch(variable, nil).to_s.strip.presence
    if from_environment
      # Said out loud, since a variable left exported would otherwise replace a token unannounced
      output.puts "Using #{variable} from the environment."
      return from_environment
    end

    output.print 'Paste the token (input hidden), then press Enter: '
    line = input.tty? ? input.noecho(&:gets) : input.gets
    output.puts
    line.to_s.strip.presence
  end
end
