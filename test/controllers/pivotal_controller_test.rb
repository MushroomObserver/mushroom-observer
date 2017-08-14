require "test_helper"

class PivotalControllerTest < FunctionalTestCase
  def test_index
    # Don't create entries on Pivotal unless enabled.
    # Unit tests for Pivotal actually post (and then delete) test comments
    # on the live pivotal account.  This is great if we really wanted to test
    # the pivotal code.  But the vast majority of the time no one was touching
    # the pivotal code, and this level of testing was not required.
    # And it generated email notifications via pivotal each time,
    # and just generally didn't seem respectful to pivotal.
    # -- per JPH
    return unless MO.pivotal_enabled

    get_with_dump(:index)
    assert_response("index")
  end
end
