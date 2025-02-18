require 'minitest/autorun'
require 'fileutils'

require_relative '../../../lib/dsl'

class RCMChainTest < Minitest::Test
  def test_chain
    configure_from_scratch do
      notify hello dear world do
        thank you to be part of you
      end
    end
  end
end
