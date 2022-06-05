# frozen_string_literal: true

require("test_helper")

class APIKeyTest < UnitTestCase
  def test_create
    count = APIKey.count

    User.current = dick
    APIKey.create
    assert_equal(count, APIKey.count)

    APIKey.create(notes: "app name")
    key = APIKey.last
    assert(key.created_at > 1.minute.ago)
    assert_nil(key.last_used)
    assert_equal(0, key.num_uses)
    assert_users_equal(dick, key.user)
    assert(key.key.length > 30)
    assert_equal("app name", key.notes)

    key.touch!
    key = APIKey.last
    assert(key.last_used > 1.minute.ago)
    assert_equal(1, key.num_uses)
  end
end
