require_relative 'lib/rcm'

desc 'Set up wireguard mesh'
task :wireguard do
  make_it_so do
    p option :verbose
    dump_config
    only_when { hostname is :earth }

    file '/tmp/test/wg/wg0.conf' do
      create_parent
      content 'the content is here'
    end
  end
end
