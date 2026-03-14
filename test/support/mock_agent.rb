# frozen_string_literal: true

mode = ARGV.shift.to_s
stdin = $stdin.read

case mode
when 'upcase_prompt'
  prompt = ARGV.fetch(0, '')
  print "#{stdin.upcase}|#{prompt}"
when 'reverse_input'
  input_path = ARGV.fetch(0)
  print File.read(input_path).reverse
when 'basename'
  file_path = ARGV.fetch(0)
  print File.basename(file_path)
when 'pass_through'
  print stdin
when 'upcase'
  print stdin.upcase
when 'fail'
  warn ARGV.fetch(0, 'boom')
  exit Integer(ARGV.fetch(1, '7'))
else
  warn "unknown mode: #{mode}"
  exit 2
end
