require 'minitest/autorun'
require 'fileutils'

require_relative '../../../lib/dsl'

class RCMDependencyTest < Minitest::Test
  def test_depends_on
    foo = nil
    bar = nil
    baz = nil

    configure_from_scratch do
      foo = notify 'foo' do
        depends_on notify 'bar', 'baz'
        :foo_message
      end

      bar = notify 'bar'

      baz = notify 'baz' do
        depends_on notify 'bar'
        :baz_message
      end
    end

    assert_equal 2, foo.depends_on.count
    assert foo.depends_on?("notify('bar')", "notify('baz')")

    assert_equal 0, bar.depends_on.count
    refute bar.depends_on?('foo')

    assert_equal 1, baz.depends_on.count
    assert baz.depends_on?("notify('bar')")
  end

  def test_depends_on_invalid_resource
    assert_raises(RCM::Keyword::KeywordError) do
      configure_from_scratch do
        notify { depends_on invalid('baz') }
      end
    end
  end

  def test_depends_on_non_existant_dependency
    assert_raises(RCM::Resource::NoSuchResourceObject) do
      configure_from_scratch do
        notify { depends_on notify('nonexistant') }
      end
    end
  end

  def test_dependency_loop
    assert_raises(RCM::DependencyEvaluator::DependencyLoop) do
      configure_from_scratch do
        notify('loop') { depends_on notify('loop') }
      end
    end
  end

  def test_dependency_loop_indirect
    assert_raises(RCM::DependencyEvaluator::DependencyLoop) do
      configure_from_scratch do
        notify('loop') { depends_on notify('pool') }
        notify('pool') { depends_on notify('loop') }
      end
    end
  end
end
