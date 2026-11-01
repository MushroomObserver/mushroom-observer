# frozen_string_literal: true

require "test_helper"

module Views::Controllers::Descriptions
  class NotesPanelsTest < ComponentTestCase
    def test_renders_a_panel_per_note_field
      desc = name_descriptions(:peltigera_alt_desc)

      html = render_panels(description: desc)

      assert_html(html, ".card-body", text: desc.gen_desc.to_s.tpl.strip_html)
    end

    def test_renders_empty_message_when_no_notes
      desc = name_descriptions(:draft_agaricus_campestris)

      html = render_panels(description: desc)

      assert_no_html(html, ".panel")
      assert_html(html, "div", text: :show_description_empty.l)
    end

    def test_renders_empty_message_for_location
      desc = LocationDescription.new(location: locations(:albion))

      html = render_panels(description: desc)

      assert_no_html(html, ".panel")
      assert_html(html, "div", text: :show_description_empty.l)
    end

    private

    def render_panels(description:)
      render(NotesPanels.new(description: description))
    end
  end
end
