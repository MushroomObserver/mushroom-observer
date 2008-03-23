require File.dirname(__FILE__) + '/../test_helper'
require 'application'

# Re-raise errors caught by the controller.
class ApplciationController; def rescue_action(e) raise e end; end

class ApplicationControllerTest < Test::Unit::TestCase

  def setup
    @controller = ApplicationController.new
  end

  # Make sure languages all have same tags.
  def test_language_tags
    dir = "#{RAILS_ROOT}/lang/ui"
    assert File.directory?(dir)
    tags = {}
    this_tags = {}
    files = Dir.glob("#{dir}/*.yml")
    assert(files.length > 0)
    for file in files
      h = this_tags[file] = {}
      for line in IO.readlines(file)
        h[$1] = tags[$1] = true if line.match(/^(\w+)/)
      end
      assert(h["app_banner"])
    end
    for file in files
      missing = tags.keys - this_tags[file].keys
      assert_equal([], missing, "Missing tags in #{file}")
    end
  end
end
