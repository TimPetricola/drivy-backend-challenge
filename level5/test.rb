require 'minitest/autorun'
require './main'

class Level5Test < Minitest::Test
  def test_output
    assert_equal File.read('output.json'), Level5.output
  end
end
