require 'minitest/autorun'
require './main'

class Level2Test < Minitest::Test
  def test_output
    assert_equal File.read('output.json'), Level2.output
  end
end
