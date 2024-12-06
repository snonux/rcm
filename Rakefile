require_relative 'rcm/rcm'

desc 'Set up wireguard mesh'
task :wireguard do |t|
  rcm do
    p option :verbose
    conditions do
      hostname is :earth
    end

    file '/etc/wg/wg0.conf' do
      content 'the content'
    end
  end
end
