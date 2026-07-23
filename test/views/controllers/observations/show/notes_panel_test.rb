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

  # A blank Other value alongside other note parts should not print
  # an empty "Other" caption -- only the parts with real content.
  def test_blank_other_omitted_from_multi_part_notes
    @obs.notes = { Substrate: "wood", Other: "" }

    html = render(panel_with(@obs))
    notes = Nokogiri::HTML.fragment(html).at_css("#observation_notes")

    assert_equal(1, notes.css(".indent").length,
                 "Blank Other value should not render its own part")
    assert_includes(notes.text, "wood")
    assert_not_includes(notes.text, "Other")
  end

  def test_whitespace_only_other_omitted_from_multi_part_notes
    @obs.notes = { Substrate: "wood", Other: "   \n  " }

    html = render(panel_with(@obs))
    notes = Nokogiri::HTML.fragment(html).at_css("#observation_notes")

    assert_equal(
      1, notes.css(".indent").length,
      "Whitespace-only Other value should not render its own part"
    )
    assert_not_includes(notes.text, "Other")
  end

  # The primary observation of a multi-member occurrence renders the
  # per-key notes merge, so a sibling's note value appears on the
  # primary's panel alongside the primary's own.
  def test_notes_merge_surfaces_sibling_values_for_primary
    primary = observations(:detailed_unknown_obs)
    sibling = observations(:coprinus_comatus_obs)
    [primary, sibling].each { |obs| obs.update_column(:occurrence_id, nil) }
    primary.update!(notes: { Cap: "red cap" })
    sibling.update!(notes: { Substrate: "on oak wood" })
    occ = Occurrence.create!(user: @user, primary_observation: primary)
    primary.update!(occurrence: occ)
    sibling.update!(occurrence: occ)

    html = render(panel_with(primary))
    notes = Nokogiri::HTML.fragment(html).at_css("#observation_notes").text

    assert_includes(notes, "red cap")      # primary's own value
    assert_includes(notes, "on oak wood")  # inherited from the sibling
  end

  private

  def panel_with(obs, user = @user)
    Views::Controllers::Observations::Show::NotesPanel.new(
      obs: obs, user: user
    )
  end
end
