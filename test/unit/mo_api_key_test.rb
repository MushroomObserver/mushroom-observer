require File.expand_path(File.dirname(__FILE__) + '/../boot.rb')

class MoApiKeyTest < UnitTestCase
  def test_create
    User.current = @dick
    MoApiKey.create
    assert_equal(0, MoApiKey.count)

    MoApiKey.create(:notes => 'app name')
    key = MoApiKey.last
    assert(key.created > 1.minute.ago)
    assert_nil(key.last_used)
    assert_equal(0, key.num_uses)
    assert_users_equal(@dick, key.user)
    assert(key.key.length > 30)
    assert_equal('app name', key.notes)

    key.touch!
    key = MoApiKey.last
    assert(key.last_used > 1.minute.ago)
    assert_equal(1, key.num_uses)
  end
end
