# encoding: utf-8
require File.expand_path(File.dirname(__FILE__) + '/../boot.rb')

# A place to put tests related to the overall RoR configuration

class ConfigTest < UnitTestCase
  def test_has_xml_parser
    assert(!ActionController::Base.param_parsers.member?(Mime::XML))
  end
end
