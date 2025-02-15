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
    assert_raises(RCM::ResourceDependencies::NoSuchResourceType) do
      configure_from_scratch do
        notify { depends_on invalid['baz'] }
      end
    end
  end
end
