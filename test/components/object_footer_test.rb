# frozen_string_literal: true

require "test_helper"
require "ostruct"

# rubocop:disable Style/OpenStructUse
class ObjectFooterTest < UnitTestCase
  include ComponentTestHelper

  def test_non_versioned_object_with_created_and_updated
    obj = OpenStruct.new(
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
    obj = OpenStruct.new(created_at: nil, updated_at: nil)

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
    obj = OpenStruct.new(
      created_at: Time.zone.parse("2024-01-15 10:00:00"),
      updated_at: Time.zone.parse("2024-01-20 15:30:00"),
      user: user,
      version: 3
    )
    version1 = OpenStruct.new(user_id: users(:mary).id)
    version2 = OpenStruct.new(user_id: users(:dick).id)
    version3 = OpenStruct.new(user_id: users(:katrina).id)
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
    obj = OpenStruct.new(
      created_at: Time.zone.parse("2024-01-15 10:00:00"),
      updated_at: Time.zone.parse("2024-01-20 15:30:00"),
      user: user,
      version: 2
    )
    version1 = OpenStruct.new(user_id: users(:mary).id)
    version2 = OpenStruct.new(user_id: nil) # No user_id
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

    obj = OpenStruct.new(
      version: 2,
      updated_at: Time.zone.parse("2024-01-15 10:00:00"),
      user_id: mary.id
    )
    version1 = OpenStruct.new(user_id: mary.id)
    version2 = OpenStruct.new(user_id: dick.id)
    version3 = OpenStruct.new(user_id: katrina.id)
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
    assert_includes(html, "user_link")
  end

  def test_old_version_without_updated_at
    user = users(:rolf)
    obj = OpenStruct.new(
      version: 1,
      updated_at: nil,
      user_id: users(:mary).id
    )
    versions = [
      OpenStruct.new(user_id: users(:mary).id),
      OpenStruct.new(user_id: users(:dick).id)
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
    obj = OpenStruct.new(
      created_at: Time.zone.parse("2024-01-15 10:00:00"),
      old_num_views: 1,
      old_last_view: Time.zone.parse("2024-01-20 10:00:00"),
      last_view: Time.zone.parse("2024-01-20 10:00:00")
    )

    # Mock the respond_to? method
    def obj.respond_to?(method)
      [:num_views, :old_num_views, :old_last_view].include?(method) || super
    end

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
    obj = OpenStruct.new(
      created_at: Time.zone.parse("2024-01-15 10:00:00"),
      old_num_views: 42,
      old_last_view: Time.zone.parse("2024-01-20 10:00:00"),
      last_view: Time.zone.parse("2024-01-20 10:00:00")
    )

    def obj.respond_to?(method)
      [:num_views, :old_num_views, :old_last_view].include?(method) || super
    end

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
    Time.zone.parse("2024-01-18 12:00:00")
    obj = OpenStruct.new(
      created_at: Time.zone.parse("2024-01-15 10:00:00")
    )

    def obj.respond_to?(method)
      method == :last_viewed_by || super
    end

    def obj.old_last_viewed_by(_user)
      Time.zone.parse("2024-01-18 12:00:00")
    end

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
    obj = OpenStruct.new(
      created_at: Time.zone.parse("2024-01-15 10:00:00")
    )

    def obj.respond_to?(method)
      method == :last_viewed_by || super
    end

    def obj.old_last_viewed_by(_user)
      nil
    end

    html = render_component(Components::ObjectFooter.new(
                              user: user,
                              obj: obj
                            ))

    assert_includes(html, "footer-view-stats")
    # Should show "never" when user hasn't viewed
    assert_match(/never/i, html)
  end

  def test_with_rss_log_link
    obj = OpenStruct.new(
      created_at: Time.zone.parse("2024-01-15 10:00:00"),
      rss_log_id: 123
    )

    def obj.respond_to?(method)
      method == :rss_log_id || super
    end

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
    obj = OpenStruct.new(
      created_at: Time.zone.parse("2024-01-15 10:00:00"),
      rss_log_id: nil
    )

    def obj.respond_to?(method)
      method == :rss_log_id || super
    end

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
    obj = OpenStruct.new(
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
    obj = OpenStruct.new(
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
end
# rubocop:enable Style/OpenStructUse
