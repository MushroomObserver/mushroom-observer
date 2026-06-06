# frozen_string_literal: true

require("test_helper")

# HTML parity test: `Components::IdBadge` vs the original
# `show_title_id_badge` helper-era markup. Rebuilds the helper's
# `tag.button(...)` output inline so the test does not depend on
# the (now-delegated) helper still being in the tree, and asserts
# byte-for-byte equality with the component's render output.
#
# Catches whitespace / attribute / class-order drift that
# selector-based component tests (`id_badge_test.rb`) would miss.
class IdBadgeParityTest < ComponentTestCase
  include Rails::Dom::Testing::Assertions::DomAssertions

  def test_show_title_id_badge_html_matches_id_badge_component
    obs = observations(:minimal_unknown_obs)

    assert_dom_equal(legacy_show_title_id_badge(obs),
                     render(Components::IdBadge.new(object: obs)))
  end

  def test_extra_class_branch_matches_legacy
    obs = observations(:minimal_unknown_obs)

    assert_dom_equal(
      legacy_show_title_id_badge(obs, "rss-id mr-4"),
      render(Components::IdBadge.new(object: obs, extra_class: "rss-id mr-4"))
    )
  end

  def test_nil_id_renders_question_mark_in_both
    # Unpersisted models render "?" in both shapes.
    obs = Observation.new

    assert_dom_equal(legacy_show_title_id_badge(obs),
                     render(Components::IdBadge.new(object: obs)))
  end

  private

  # Inlined copy of the legacy `header/title_helper.rb#show_title_id_badge`
  # body (the pre-Phlex implementation), so the parity test does not
  # rely on the still-extant delegate stub.
  def legacy_show_title_id_badge(object, classes = "mr-4")
    view_context.tag.button(
      object.id || "?",
      type: "button",
      class: ["badge badge-id", classes].compact.join(" "),
      role: "button",
      data: {
        toggle: "tooltip", placement: "bottom", title: :COPY_THIS_ID.l,
        controller: "clipboard", clipboard_target: "source",
        action: "clipboard#copy", clipboard_copied_value: :COPIED.l
      }
    )
  end
end
