# encoding: utf-8
require 'test_helper'

# A place to put tests related to the overall RoR configuration

class ConfigTest < ActiveSupport::TestCase
  def test_has_xml_parser
    assert(!ActionController::Base.param_parsers.member?(Mime::XML))
  end
end
