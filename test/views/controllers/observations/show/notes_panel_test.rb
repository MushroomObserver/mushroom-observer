# frozen_string_literal: true

require("test_helper")

class Views::Controllers::Observations::Show::NotesPanelTest < ComponentTestCase
  def setup
    super
    @user = users(:rolf)
    @obs = observations(:detailed_unknown_obs)
  end

  def test_renders_panel_id
    @obs.notes = { Other: "field notes here" }

    html = render(panel_with(@obs))

    assert_html(html, "#observation_notes")
  end

  def test_renders_nothing_when_no_notes
    @obs.notes = ::Observation.no_notes

    html = render(panel_with(@obs))

    assert_no_html(html, "#observation_notes")
  end

  def test_notes_render_without_collector_special_casing
    @obs.notes = { Substrate: "wood", Other: "field notes here" }

    html = render(panel_with(@obs))
    notes = Nokogiri::HTML.fragment(html).at_css("#observation_notes").text

    assert_includes(notes, "field notes here")
    assert_includes(notes, "wood")
  end

  # A note value with blank lines must not truncate at the first blank
  # line; each value renders as a textile block indented beneath its
  # caption, with blank lines preserved as separate paragraphs.
  def test_notes_with_blank_lines_not_truncated
    @obs.notes = { Substrate: "wood",
                   Other: "first paragraph\n\nsecond paragraph\n\nthird" }

    html = render(panel_with(@obs))
    notes = Nokogiri::HTML.fragment(html).at_css("#observation_notes")

    # All three paragraphs present (no truncation at the first blank line).
    assert_includes(notes.text, "first paragraph")
    assert_includes(notes.text, "second paragraph")
    assert_includes(notes.text, "third")
    # The Other value's blank lines survive as separate textile
    # paragraphs (3), plus one for the single-paragraph Substrate value.
    assert_operator(notes.css("p").length, :>=, 4,
                    "Blank lines should render as separate paragraphs")
    assert_includes(notes.text, "wood")
  end

  private

  def panel_with(obs, user = @user)
    Views::Controllers::Observations::Show::NotesPanel.new(
      obs: obs, user: user
    )
  end
end
