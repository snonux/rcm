require 'minitest/autorun'
require 'fileutils'

require_relative '../../../lib/dsl'

class RCMDependencyTest < Minitest::Test
  def test_depends_on
    configure_from_scratch do
      notify 'foo' do
        depends_on notify['bar'], notify['baz']
        :foo_message
      end

      notify 'bar'

      notify 'baz' do
        depends_on notify['bar']
        :baz_message
      end
    end
  end

  def test_depends_on_invalid_resource
    correct_exception_thrown = false

    configure_from_scratch do
      notify 'foo' do
        depends_on invalid['baz']
        :foo_message
      end
    rescue RCM::ResourceDependencies::NoSuchResource
      correct_exception_thrown = true
    end

    assert correct_exception_thrown
  end
end
