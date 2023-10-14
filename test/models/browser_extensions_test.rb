# frozen_string_literal: true

require("test_helper")


# test MO extensions to the browser gem, https://github.com/fnando/browser
class BrowserExtensionsTest < UnitTestCase
  def test_bot
    assert_not(Browser.new("").bot?,
               "Browser gem should ignore empty ua's in tests")

    # known bots: https://github.com/fnando/browser/blob/master/bots.yml
    assert(Browser.new("AdvBot").bot?,
           "Browser gem should detect known bad ua's in tests")
  end
end
