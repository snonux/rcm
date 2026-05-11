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
when 'join_args'
  print ARGV.join('|')
when 'count_pass_through'
  counter_path = ARGV.fetch(0)
  count = File.file?(counter_path) ? File.read(counter_path).to_i : 0
  File.write(counter_path, count + 1)
  print stdin
when 'count_upcase'
  counter_path = ARGV.fetch(0)
  count = File.file?(counter_path) ? File.read(counter_path).to_i : 0
  File.write(counter_path, count + 1)
  print stdin.upcase
when 'fail_then_pass'
  counter_path = ARGV.fetch(0)
  failures_before_success = Integer(ARGV.fetch(1, '1'))
  message = ARGV.fetch(2, 'boom')
  exit_code = Integer(ARGV.fetch(3, '7'))
  count = File.file?(counter_path) ? File.read(counter_path).to_i : 0
  count += 1
  File.write(counter_path, count)
  if count <= failures_before_success
    warn message
    exit exit_code
  end
  print stdin
when 'stream_chunks'
  stderr_text = ARGV.pop.sub('--stderr=', '') if ARGV.last&.start_with?('--stderr=')
  ARGV.each do |chunk|
    $stdout.write(chunk)
    $stdout.flush
    sleep 0.01
  end
  if stderr_text
    $stderr.write(stderr_text)
    $stderr.flush
  end
when 'count_or_fail'
  counter_path = ARGV.fetch(0)
  marker_path = ARGV.fetch(1)
  if File.exist?(marker_path)
    warn ARGV.fetch(2, 'boom')
    exit Integer(ARGV.fetch(3, '7'))
  end
  count = File.file?(counter_path) ? File.read(counter_path).to_i : 0
  File.write(counter_path, count + 1)
  print stdin
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
