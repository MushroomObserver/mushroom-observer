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

  # An observation with a thumbnail uses it (the common case).
  def test_observation_uses_thumb_image
    obs = observations(:coprinus_comatus_obs)
    assert(obs.thumb_image_id, "fixture should have a thumb_image")
    component = Components::Matrix::Box.new(user: @user, object: obs)

    assert_equal(obs.thumb_image, component.build_render_data[:image])
  end

  # #5314 follow-up: an observation with images but a null thumbnail
  # falls back to its oldest image so the box is not blank.
  def test_observation_falls_back_to_first_image_when_thumb_missing
    obs = observations(:coprinus_comatus_obs)
    obs.update_columns(thumb_image_id: nil)
    obs = Observation.find(obs.id)
    assert(obs.images.any?, "fixture should have at least one image")
    component = Components::Matrix::Box.new(user: @user, object: obs)

    assert_equal(obs.images.min_by(&:id), component.build_render_data[:image])
  end

  # No images and no thumbnail: the box carries no image.
  def test_observation_without_images_has_no_image_data
    obs = observations(:minimal_unknown_obs)
    obs.images = []
    obs.update_columns(thumb_image_id: nil)
    obs = Observation.find(obs.id)
    component = Components::Matrix::Box.new(user: @user, object: obs)

    assert_nil(component.build_render_data[:image])
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

  # ---------------------------------------------------------------
  # rss_log_detail_tag
  # ---------------------------------------------------------------

  # #parse_log can return [] when notes is blank -- target_recently_
  # created?'s `log.last[2]` (and friends) then indexes into a nil,
  # raising. RssLog#detail used to rescue exactly this same selection
  # logic (dev: degrade silently; production: raise) before it moved
  # here (#4868 follow-up) -- confirm the same protection survived
  # the move. Hard to construct a real RssLog that naturally reaches
  # this state (see the file-level comment), so stub the pieces
  # directly.
  def test_rss_log_detail_tag_degrades_gracefully_on_malformed_log
    rss_log = rss_logs(:coprinus_comatus_obs_rss_log)
    component = Components::Matrix::Box.new(user: @user, object: rss_log)

    result = rss_log.stub(:parse_log, []) do
      rss_log.stub(:created_at, nil) do
        rss_log.stub(:orphan?, false) do
          component.rss_log_detail_tag(rss_log)
        end
      end
    end

    assert_nil(result)
  end

  def test_rss_log_detail_tag_raises_in_production
    rss_log = rss_logs(:coprinus_comatus_obs_rss_log)
    component = Components::Matrix::Box.new(user: @user, object: rss_log)

    Rails.env.stub(:production?, true) do
      rss_log.stub(:parse_log, []) do
        rss_log.stub(:created_at, nil) do
          rss_log.stub(:orphan?, false) do
            assert_raises(NoMethodError) do
              component.rss_log_detail_tag(rss_log)
            end
          end
        end
      end
    end
  end
end
