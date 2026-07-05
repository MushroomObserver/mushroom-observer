# frozen_string_literal: true

require("test_helper")

# Tests for Components::Matrix::Box::RenderData, the mixin included by
# Components::Matrix::Box that builds the `@data` hash consumed by the
# box's rendering methods.
#
# Most branches are already exercised through a full Box render (see
# box_test.rb). A handful of branches — the `:unknown` object-type
# fallback, the rescued `nil` "when" on a broken Image, and two
# RssLog-target edge cases — either can't be reached through a full
# render (the box's other rendering methods assume a recognized
# `@data[:type]`) or need a target state fixtures can't express
# directly. Those are tested by calling the (public) RenderData
# methods directly on a Box instance — same technique used by
# footer_test.rb for its content methods.
class MatrixBoxRenderDataTest < ComponentTestCase
  def setup
    super
    @user = users(:rolf)
  end

  # ---------------------------------------------------------------
  # build_render_data
  # ---------------------------------------------------------------

  # Any AbstractModel that isn't Image/Observation/RssLog/User falls
  # into the `else` branch — a bare `{ id:, type: :unknown }` hash.
  def test_build_render_data_unknown_object_type
    location = locations(:albion)
    component = Components::Matrix::Box.new(user: @user, object: location)

    assert_equal({ id: location.id, type: :unknown },
                 component.build_render_data)
  end

  # ---------------------------------------------------------------
  # extract_image_data
  # ---------------------------------------------------------------

  # `@object.when.web_date` is wrapped in a rescue — an Image with a
  # nil `when` raises NoMethodError on `.web_date`, which is caught
  # and reported as a nil `:when`, rather than blowing up the box.
  def test_extract_image_data_when_nil_on_error
    image = images(:in_situ_image).dup
    image.when = nil
    component = Components::Matrix::Box.new(user: @user, object: image)

    assert_nil(component.extract_image_data[:when])
  end

  # ---------------------------------------------------------------
  # extract_rss_log_name
  # ---------------------------------------------------------------

  # `RssLog::ALL_TYPES` doesn't currently include Image, so this
  # branch can't be reached with a real RssLog fixture — stub
  # `target_type` to exercise it directly.
  def test_extract_rss_log_name_image_target_type
    rss_log = rss_logs(:coprinus_comatus_obs_rss_log)
    image = images(:in_situ_image)
    component = Components::Matrix::Box.new(user: @user, object: rss_log)

    name = rss_log.stub(:target_type, :image) do
      component.extract_rss_log_name(image)
    end

    assert_equal(image.unique_format_name.t, name)
  end

  # An orphaned RssLog (no live target) falls back to formatting the
  # RssLog itself.
  def test_extract_rss_log_name_orphaned_log_uses_rss_log_itself
    rss_log = RssLog.new(notes: "orphaned title\n")
    component = Components::Matrix::Box.new(user: @user, object: rss_log)

    name = component.extract_rss_log_name(nil)

    assert_equal(rss_log.format_name.t.break_name.small_author, name)
  end
end
