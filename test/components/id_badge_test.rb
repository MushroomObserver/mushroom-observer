# frozen_string_literal: true

require("test_helper")

class IDBadgeTest < ComponentTestCase
  def test_renders_object_id_in_clipboard_button
    obs = observations(:minimal_unknown_obs)
    html = render(Components::IDBadge.new(object: obs, size: :md))

    # The badge is a `<button>` whose visible content is the object id.
    assert_html(html, "button[type='button']", text: obs.id.to_s)
    # Stimulus clipboard wiring — each data attr asserted
    # independently so a single rename doesn't cascade into one
    # giant compound-selector failure.
    assert_html(html, "button[data-controller='clipboard']")
    assert_html(html, "button[data-clipboard-target='source']")
    assert_html(html, "button[data-action='clipboard#copy']")
  end

  def test_renders_question_mark_when_object_id_nil
    # Newly-built (unpersisted) model has no id — fall back to "?"
    # so the badge still renders without a NoMethodError.
    html = render(Components::IDBadge.new(object: Observation.new, size: :md))

    assert_html(html, "button", text: "?")
  end

  def test_renders_value_when_no_object_given
    # Not an AbstractModel id -- e.g. an external site's own numeric id
    # (see Components::Link::External).
    html = render(Components::IDBadge.new(
                    value: "234723", size: :lg, extra_class: nil
                  ))

    assert_html(html, "button[type='button']", text: "234723")
    assert_html(html, "button[data-controller='clipboard']")
  end

  def test_object_id_wins_over_value_when_both_given
    obs = observations(:minimal_unknown_obs)
    html = render(Components::IDBadge.new(
                    object: obs, value: "999999", size: :md
                  ))

    assert_html(html, "button", text: obs.id.to_s)
  end

  def test_extra_class_overrides_default_spacing
    obs = observations(:minimal_unknown_obs)
    html = render(Components::IDBadge.new(
                    object: obs, size: :md, extra_class: "custom-class"
                  ))

    # Caller-supplied extra_class joins the base `badge badge-id`
    # classes.
    assert_html(html, "button.badge.badge-id.custom-class")
  end

  def test_size_maps_to_badge_size_class
    obs = observations(:minimal_unknown_obs)

    { xl: "badge-xl", lg: "badge-lg",
      md: "badge-md", sm: "badge-sm" }.each do |size, css_class|
      html = render(Components::IDBadge.new(object: obs, size: size))

      assert_html(html, "button.badge-id.#{css_class}")
    end
  end

  def test_requires_size
    obs = observations(:minimal_unknown_obs)

    assert_raises(ArgumentError) { Components::IDBadge.new(object: obs) }
  end

  def test_default_tooltip_title
    obs = observations(:minimal_unknown_obs)
    html = render(Components::IDBadge.new(object: obs, size: :md))

    assert_html(html, "button[data-title='#{:copy_this_id.ti}']")
  end

  def test_title_prop_overrides_default_tooltip_title
    obs = observations(:minimal_unknown_obs)
    html = render(Components::IDBadge.new(
                    object: obs, size: :md, title: "Copy Foo ID"
                  ))

    assert_html(html, "button[data-title='Copy Foo ID']")
    assert_no_html(html, "button[data-title='#{:copy_this_id.ti}']")
  end
end
