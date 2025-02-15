require 'minitest/autorun'
require 'fileutils'

require_relative '../../../lib/dsl'

class RCMDependencyTest < Minitest::Test
  def test_dependency
    configure_from_scratch do
      notify 'foo' do
        depends_on notify['bar'], file['baz']
        :HELLO
      end

      notify 'bar'
    end
  end
end
