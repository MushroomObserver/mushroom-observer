# frozen_string_literal: true

require("test_helper")

class APIKeyTest < UnitTestCase
  def test_create
    count = APIKey.count

    APIKey.create
    assert_equal(count, APIKey.count)

    APIKey.create(notes: "app name", current_user: dick)
    key = APIKey.find_by(notes: "app name", user: dick)
    assert_not_nil(key, "Cannot find APIKey")
    assert(key.created_at > 1.minute.ago)
    assert_nil(key.last_used)
    assert_equal(0, key.num_uses)
    assert_users_equal(dick, key.user)
    assert(key.key.length > 30)
    assert_equal("app name", key.notes)

    key.touch!
    key.reload
    assert(key.last_used > 1.minute.ago)
    assert_equal(1, key.num_uses)
  end

  def test_show_controller_and_index_action
    assert_equal("/account", APIKey.show_controller)
    assert_equal(:api_keys, APIKey.index_action)
  end

  def test_check_key_rejects_duplicate_key
    original = APIKey.create!(notes: "original", current_user: dick,
                              key: "duplicate_test_key")
    dupe = APIKey.new(notes: "dupe", current_user: rolf,
                      key: "duplicate_test_key")

    assert_not(dupe.valid?)
    assert_includes(dupe.errors[:key], "api keys must be unique")

    original.destroy
  end
end
