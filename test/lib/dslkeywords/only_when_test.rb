require 'minitest/autorun'
require 'socket'

require_relative '../../../lib/dsl'

class RCMOnlyWhenTest < Minitest::Test
  def test_hostname
    rcm = configure_from_scratch do
      only_when { hostname Socket.gethostname }
    end
    assert rcm.conds_met
  end

  def test_hostname_negative
    rcm = configure_from_scratch do
      only_when { hostname "#{Socket.gethostname}.invalid" }
    end
    refute rcm.conds_met
  end
end
