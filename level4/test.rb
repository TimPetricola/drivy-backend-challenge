require 'minitest/autorun'
require './main'

class Level4Test < Minitest::Test
  def test_output
    assert_equal File.read('output.json'), Level4.output
  end
end
