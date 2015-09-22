require 'minitest/autorun'
require './main'

class Level6Test < Minitest::Test
  def test_output
    assert_equal File.read('output.json'), Level6.output
  end
end
