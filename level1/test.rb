require 'minitest/autorun'
require './main'

class Level1Test < Minitest::Test
  def test_output
    assert_equal File.read('output.json'), Level1.output
  end
end
