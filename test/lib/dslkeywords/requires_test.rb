require 'minitest/autorun'
require 'fileutils'

require_relative '../../../lib/dsl'

class RCMRequiresTest < Minitest::Test
  def test_requires
    foo_notify = bar_notify = baz_notify = nil

    configure_from_scratch do
      foo_notify = notify foo do
        requires notify bar and requires notify baz
        foo_message
      end

      bar_notify = notify bar

      baz_notify = notify baz do
        requires notify bar
        baz_message
      end
    end

    assert_equal 2, foo_notify.requires.count
    assert foo_notify.requires?("notify('bar')", "notify('baz')")

    assert_equal 0, bar_notify.requires.count
    refute bar_notify.requires?('foo')

    assert_equal 1, baz_notify.requires.count
    assert baz_notify.requires?("notify('bar')")
  end

  def test_requires_invalid_resource
    assert_raises(NameError) do
      configure_from_scratch do
        notify { requires invalid('baz') }
      end
    end
  end

  def test_requires_non_existant_dependency
    assert_raises(RCM::Resource::NoSuchResourceObject) do
      configure_from_scratch do
        notify { requires notify nonexistant }
      end
    end
  end

  def test_dependency_loop
    assert_raises(RCM::DependencyEvaluator::DependencyLoop) do
      configure_from_scratch do
        notify(looper) { requires notify looper }
      end
    end
  end

  def test_dependency_loop_indirect
    assert_raises(RCM::DependencyEvaluator::DependencyLoop) do
      configure_from_scratch do
        notify(looper) { requires notify pooler }
        notify(pooler) { requires notify looper }
      end
    end
  end
end
