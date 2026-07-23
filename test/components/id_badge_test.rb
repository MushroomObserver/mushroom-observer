# frozen_string_literal: true

require("test_helper")

class IDBadgeTest < ComponentTestCase
  def test_renders_object_id_in_clipboard_button
    obs = observations(:minimal_unknown_obs)
    html = render(Components::IDBadge.new(object: obs))

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
    html = render(Components::IDBadge.new(object: Observation.new))

    assert_html(html, "button", text: "?")
  end

  def test_renders_value_when_no_object_given
    # Not an AbstractModel id -- e.g. an external site's own numeric id
    # (see Components::Link::External).
    html = render(Components::IDBadge.new(value: "234723", extra_class: nil))

    assert_html(html, "button[type='button']", text: "234723")
    assert_html(html, "button[data-controller='clipboard']")
  end

  def test_object_id_wins_over_value_when_both_given
    obs = observations(:minimal_unknown_obs)
    html = render(Components::IDBadge.new(object: obs, value: "999999"))

    assert_html(html, "button", text: obs.id.to_s)
  end

  def test_extra_class_overrides_default_spacing
    obs = observations(:minimal_unknown_obs)
    html = render(Components::IDBadge.new(
                    object: obs, extra_class: "rss-id mr-4"
                  ))

    # Caller-supplied extra_class joins the base `badge badge-id`
    # classes — used by the rss-feed flavour from the name index.
    assert_html(html, "button.badge.badge-id.rss-id.mr-4")
  end
end
