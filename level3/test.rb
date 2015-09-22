require 'minitest/autorun'
require './main'

class Level3Test < Minitest::Test
  def test_output
    assert_equal File.read('output.json'), Level3.output
  end
end
