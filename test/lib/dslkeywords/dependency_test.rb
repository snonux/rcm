require 'minitest/autorun'
require 'fileutils'

require_relative '../../../lib/dsl'

class RCMDependencyTest < Minitest::Test
  def test_requires
    foo = nil
    bar = nil
    baz = nil

    configure_from_scratch do
      foo = notify 'foo' do
        requires notify 'bar', 'baz'
        :foo_message
      end

      bar = notify 'bar'

      baz = notify 'baz' do
        requires notify 'bar'
        :baz_message
      end
    end

    assert_equal 2, foo.requires.count
    assert foo.requires?("notify('bar')", "notify('baz')")

    assert_equal 0, bar.requires.count
    refute bar.requires?('foo')

    assert_equal 1, baz.requires.count
    assert baz.requires?("notify('bar')")
  end

  def test_requires_invalid_resource
    assert_raises(RCM::Keyword::KeywordError) do
      configure_from_scratch do
        notify { requires invalid('baz') }
      end
    end
  end

  def test_requires_non_existant_dependency
    assert_raises(RCM::Resource::NoSuchResourceObject) do
      configure_from_scratch do
        notify { requires notify('nonexistant') }
      end
    end
  end

  def test_dependency_loop
    assert_raises(RCM::DependencyEvaluator::DependencyLoop) do
      configure_from_scratch do
        notify('loop') { requires notify('loop') }
      end
    end
  end

  def test_dependency_loop_indirect
    assert_raises(RCM::DependencyEvaluator::DependencyLoop) do
      configure_from_scratch do
        notify('loop') { requires notify('pool') }
        notify('pool') { requires notify('loop') }
      end
    end
  end
end
