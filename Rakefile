require_relative 'lib/rcm'

desc 'Set up wireguard mesh'
task :wireguard do
  make_it_so do
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
  make_it_so do
    file :alias, '/tmp/test.txt' do
      [ 'foo', 'bar', 'baz' ].sort
    end
  end
end 
