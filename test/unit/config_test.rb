# encoding: utf-8
require 'test_helper'

# A place to put tests related to the overall RoR configuration

class ConfigTest < UnitTestCase
  # Not sure why we are testing this.  Used to be false, but it's true with Rails 3
  def test_has_xml_parser
    assert(ActionDispatch::ParamsParser::DEFAULT_PARSERS.member?(Mime::XML))
  end
end
