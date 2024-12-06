require_relative 'lib/rcm'

desc 'Set up wireguard mesh'
task :wireguard do
  make_it_so do
    p option :verbose
    dump_config
    only_when { hostname is :earth }

    file '/etc/wg/wg0.conf' do
      content 'the content'
    end
  end
end
