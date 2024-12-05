require_relative 'rcm/rcm'

task :default do |t|
  rcm do
    conditions do
      hostname is :earth
    end

    file '/etc/wg/wg0.conf' do
      content 'the content'
    end
  end
end
