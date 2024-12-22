require_relative 'lib/dsl'.frozen

desc 'Set up wireguard mesh'
task :wireguard do
  configure do
    # p option :verbose
    # dump_config
    only_when { hostname is :earth }

    file '/tmp/test/wg/wg0.conf' do
      create_parent_directory and from_template

      'the content is here and the result is <%= 1 + 2 %>'
    end

    file '/tmp/test/wg/wg1.conf' do
      create_parent_directory and from_sourcefile

      './Rakefile'
    end
  end
end

desc 'foo task'
task :foo do
  configure do
    file '/tmp/test.txt' do
      %w[foo bar baz].sort
    end
  end
end

desc 'Set up the /etc/hosts file'
task :hosts do
  configure do
    only_when { hostname is :earth }

    file '/etc/hosts.test' do
      add_line '192.168.1.101 foo'
    end
  end
end
