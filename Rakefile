require_relative 'lib/rcm'

desc 'Set up wireguard mesh'
task :wireguard do
  make_it_so do
    # p option :verbose
    # dump_config
    only_when { hostname is :earth }

    file '/tmp/test/wg/wg0.conf' do
      create_parent_directory
      from_template content 'the content is here and the result is <%= 1 + 2 %>'
    end

    file '/tmp/test/wg/wg1.conf' do
      create_parent_directory
      from_file content './Rakefile'
    end
  end
end
