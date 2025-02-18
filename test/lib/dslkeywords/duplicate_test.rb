require 'minitest/autorun'
require 'fileutils'
require_relative '../../../lib/dsl'

class RCMDuplicateTest < Minitest::Test
  def test_duplicate_definitioin
    assert_raises(RCM::DSL::DuplicateResource) do
      configure_from_scratch do
        notify :foo
        notify :foo
      end
    end
  end
end
