# frozen_string_literal: true

require "test_helper"

class ObjectFooterTest < ComponentTestCase

  # Test double for objects with footer metadata
  class TestObject
    attr_reader :created_at, :updated_at, :user, :user_id, :version,
                :old_num_views, :old_last_view, :last_view, :rss_log_id

    def initialize(**attrs)
      attrs.each { |key, value| instance_variable_set("@#{key}", value) }
    end

    def respond_to?(method, *)
      instance_variable_defined?("@#{method}") || super
    end

    def old_last_viewed_by(_user)
      @last_viewed_by_time
    end
  end

  # Test double for version objects
  class TestVersion
    attr_reader :user_id

    def initialize(user_id:)
      @user_id = user_id
    end
  end

  def test_non_versioned_object_with_created_and_updated
    obj = TestObject.new(
      created_at: Time.zone.parse("2024-01-15 10:00:00"),
      updated_at: Time.zone.parse("2024-01-20 15:30:00")
    )

    html = render_component(Components::ObjectFooter.new(
                              user: nil,
                              obj: obj
                            ))

    assert_includes(html, "footer-view-stats")
    assert_includes(html, "2024-01-15")
    assert_includes(html, "2024-01-20")
  end

  def test_non_versioned_object_without_timestamps
    obj = TestObject.new(created_at: nil, updated_at: nil)

    html = render_component(Components::ObjectFooter.new(
                              user: nil,
                              obj: obj
                            ))

    assert_includes(html, "footer-view-stats")
    # Should render the container but without dates
    assert_not_includes(html, "Created")
    assert_not_includes(html, "Last modified")
  end

  def test_latest_version_with_user_and_versions
    user = users(:rolf)
    obj = TestObject.new(
      created_at: Time.zone.parse("2024-01-15 10:00:00"),
      updated_at: Time.zone.parse("2024-01-20 15:30:00"),
      user: user,
      version: 3
    )
    version1 = TestVersion.new(user_id: users(:mary).id)
    version2 = TestVersion.new(user_id: users(:dick).id)
    version3 = TestVersion.new(user_id: users(:katrina).id)
    versions = [version1, version2, version3]

    html = render_component(Components::ObjectFooter.new(
                              user: user,
                              obj: obj,
                              versions: versions
                            ))

    assert_includes(html, "footer-view-stats")
    # Should show created by original user
    assert_includes(html, "Rolf")
    # Should show last updated by latest version user
    assert_includes(html, "Katrina")
    assert_includes(html, "2024-01-15")
    assert_includes(html, "2024-01-20")
  end

  def test_latest_version_without_last_user_id
    user = users(:rolf)
    obj = TestObject.new(
      created_at: Time.zone.parse("2024-01-15 10:00:00"),
      updated_at: Time.zone.parse("2024-01-20 15:30:00"),
      user: user,
      version: 2
    )
    version1 = TestVersion.new(user_id: users(:mary).id)
    version2 = TestVersion.new(user_id: nil) # No user_id
    versions = [version1, version2]

    html = render_component(Components::ObjectFooter.new(
                              user: user,
                              obj: obj,
                              versions: versions
                            ))

    assert_includes(html, "footer-view-stats")
    # Should show created by
    assert_includes(html, "Rolf")
    # Should show last modified date but not user
    # (since version2.user_id is nil)
    assert_includes(html, "2024-01-20")
  end

  def test_old_version_of_versioned_object
    rolf = users(:rolf)
    mary = users(:mary)
    dick = users(:dick)
    katrina = users(:katrina)

    obj = TestObject.new(
      version: 2,
      updated_at: Time.zone.parse("2024-01-15 10:00:00"),
      user_id: mary.id
    )
    version1 = TestVersion.new(user_id: mary.id)
    version2 = TestVersion.new(user_id: dick.id)
    version3 = TestVersion.new(user_id: katrina.id)
    versions = [version1, version2, version3]

    html = render_component(Components::ObjectFooter.new(
                              user: rolf,
                              obj: obj,
                              versions: versions
                            ))

    assert_includes(html, "footer-view-stats")
    # Should show version number
    assert_match(/Version.*2.*of.*3/, html)
    # Should show modified date and user link
    assert_includes(html, "2024-01-15")
    # Should have a user link (verifies user_link was called)
    assert_includes(html, "Mary")
  end

  def test_old_version_without_updated_at
    user = users(:rolf)
    obj = TestObject.new(
      version: 1,
      updated_at: nil,
      user_id: users(:mary).id
    )
    versions = [
      TestVersion.new(user_id: users(:mary).id),
      TestVersion.new(user_id: users(:dick).id)
    ]

    html = render_component(Components::ObjectFooter.new(
                              user: user,
                              obj: obj,
                              versions: versions
                            ))

    assert_includes(html, "footer-view-stats")
    # Should show version number
    assert_match(/Version.*1.*of.*2/, html)
    # Should not show modified line since updated_at is nil
    assert_not_includes(html, "Mary")
  end

  def test_with_view_counts_single_view
    user = users(:rolf)
    obj = TestObject.new(
      created_at: Time.zone.parse("2024-01-15 10:00:00"),
      old_num_views: 1,
      old_last_view: Time.zone.parse("2024-01-20 10:00:00"),
      last_view: Time.zone.parse("2024-01-20 10:00:00"),
      num_views: 1
    )

    html = render_component(Components::ObjectFooter.new(
                              user: user,
                              obj: obj
                            ))

    assert_includes(html, "footer-view-stats")
    # Should show "once" for single view
    assert_match(/once/i, html)
    assert_includes(html, "2024-01-20")
  end

  def test_with_view_counts_multiple_views
    user = users(:rolf)
    obj = TestObject.new(
      created_at: Time.zone.parse("2024-01-15 10:00:00"),
      old_num_views: 42,
      old_last_view: Time.zone.parse("2024-01-20 10:00:00"),
      last_view: Time.zone.parse("2024-01-20 10:00:00"),
      num_views: 42
    )

    html = render_component(Components::ObjectFooter.new(
                              user: user,
                              obj: obj
                            ))

    assert_includes(html, "footer-view-stats")
    # Should show count for multiple views
    assert_includes(html, "42")
  end

  def test_with_last_viewed_by_user
    user = users(:rolf)
    obj = TestObject.new(
      created_at: Time.zone.parse("2024-01-15 10:00:00"),
      last_viewed_by: true,
      last_viewed_by_time: Time.zone.parse("2024-01-18 12:00:00")
    )

    html = render_component(Components::ObjectFooter.new(
                              user: user,
                              obj: obj
                            ))

    assert_includes(html, "footer-view-stats")
    # Should show when user last viewed
    assert_includes(html, "2024-01-18")
  end

  def test_with_last_viewed_by_user_never_viewed
    user = users(:rolf)
    obj = TestObject.new(
      created_at: Time.zone.parse("2024-01-15 10:00:00"),
      last_viewed_by: true,
      last_viewed_by_time: nil
    )

    html = render_component(Components::ObjectFooter.new(
                              user: user,
                              obj: obj
                            ))

    assert_includes(html, "footer-view-stats")
    # Should show "never" when user hasn't viewed
    assert_match(/never/i, html)
  end

  def test_with_rss_log_link
    obj = TestObject.new(
      created_at: Time.zone.parse("2024-01-15 10:00:00"),
      rss_log_id: 123
    )

    html = render_component(Components::ObjectFooter.new(
                              user: nil,
                              obj: obj
                            ))

    assert_includes(html, "footer-view-stats")
    # Should include link to activity log
    assert_includes(html, "activity_logs/123")
    assert_match(/log/i, html)
  end

  def test_without_rss_log_link
    obj = TestObject.new(
      created_at: Time.zone.parse("2024-01-15 10:00:00"),
      rss_log_id: nil
    )

    html = render_component(Components::ObjectFooter.new(
                              user: nil,
                              obj: obj
                            ))

    assert_includes(html, "footer-view-stats")
    # Should not include activity log link
    assert_not_includes(html, "activity_logs")
  end

  def test_with_real_name_fixture
    name = names(:fungi)
    versions = name.versions.to_a

    html = render_component(Components::ObjectFooter.new(
                              user: users(:rolf),
                              obj: name,
                              versions: versions
                            ))

    assert_includes(html, "footer-view-stats")
    # Should render without errors
    assert_not_nil(html)
  end

  def test_with_real_location_fixture
    location = locations(:albion)
    versions = location.versions.to_a

    html = render_component(Components::ObjectFooter.new(
                              user: users(:rolf),
                              obj: location,
                              versions: versions
                            ))

    assert_includes(html, "footer-view-stats")
    assert_not_nil(html)
  end

  def test_with_collection_proxy_versions
    name = names(:fungi)
    # Pass the collection proxy directly, not converted to array
    versions = name.versions

    html = render_component(Components::ObjectFooter.new(
                              user: users(:rolf),
                              obj: name,
                              versions: versions
                            ))

    assert_includes(html, "footer-view-stats")
    # Should handle ActiveRecord::Associations::CollectionProxy
    assert_not_nil(html)
  end

  def test_with_empty_versions_array
    obj = TestObject.new(
      created_at: Time.zone.parse("2024-01-15 10:00:00"),
      user: users(:rolf)
    )

    html = render_component(Components::ObjectFooter.new(
                              user: users(:rolf),
                              obj: obj,
                              versions: []
                            ))

    assert_includes(html, "footer-view-stats")
    # Should treat as non-versioned object
    assert_includes(html, "2024-01-15")
  end

  def test_default_versions_parameter
    obj = TestObject.new(
      created_at: Time.zone.parse("2024-01-15 10:00:00")
    )

    html = render_component(Components::ObjectFooter.new(
                              user: nil,
                              obj: obj
                            ))

    assert_includes(html, "footer-view-stats")
    # Should work without explicitly passing versions
    assert_includes(html, "2024-01-15")
  end

  def test_created_by_has_correct_order
    user = users(:rolf)
    obj = TestObject.new(
      created_at: Time.zone.parse("2024-01-15 10:00:00"),
      user: user,
      version: 1
    )
    version1 = TestVersion.new(user_id: user.id)
    versions = [version1]

    html = render_component(Components::ObjectFooter.new(
                              user: user,
                              obj: obj,
                              versions: versions
                            ))

    # Verify that "Created:" appears before the username
    # This is a regression test for the issue where user_link
    # rendered before the translation string
    created_index = html.index("Created")
    user_index = html.index(user.login)

    assert_not_nil(created_index, "Should contain 'Created'")
    assert_not_nil(user_index, "Should contain username")
    assert(created_index < user_index,
           "Created should appear before username, but got:\n#{html}")
  end
end
