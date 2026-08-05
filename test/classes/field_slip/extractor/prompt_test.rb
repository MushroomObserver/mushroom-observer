# frozen_string_literal: true

require("test_helper")

class FieldSlip::Extractor::PromptTest < UnitTestCase
  def setup
    @obs = observations(:minimal_unknown_obs)
    @project = projects(:eol_project)
    @project.observations << @obs unless @project.observations.include?(@obs)
  end

  def prompt(obs = @obs)
    context = FieldSlip::Extractor::Context.new(observation: obs)
    FieldSlip::Extractor::Prompt.new(context).to_s
  end

  def test_asks_for_every_field_by_its_exact_key
    text = prompt
    FieldSlip::Extractor::FIELDS.each_key do |field|
      assert_includes(text, field, "prompt must name #{field}")
    end
  end

  def test_asks_for_json_with_confidence
    text = prompt

    assert_includes(text, "fields")
    assert_includes(text, "confidence")
    assert_includes(text, "JSON")
  end

  # An observation's other photos go through the same prompt, and the
  # alias tables below are a standing invitation to answer from them
  # rather than from the image.
  def test_tells_the_model_how_to_report_an_image_with_no_slip
    text = prompt

    assert_includes(text, "slip_present")
    assert_includes(text, "does not show a field slip")
    assert_includes(text, "never a source of answers")
  end

  # Most slips leave several boxes empty and some fill in only one, so
  # a null is only worth chasing into another photo when the box had
  # writing the camera missed.
  def test_asks_which_nulls_were_written_but_unreadable
    text = prompt

    assert_includes(text, "unreadable")
    assert_includes(text, "left empty is not unreadable")
  end

  # The whole point of building the prompt from the database: the walk
  # numbers a foray actually uses, not a list written into the code.
  def test_includes_the_projects_location_aliases
    ProjectAlias.create!(project: @project, name: "EB2",
                         target: locations(:albion))

    text = prompt

    assert_includes(text, "EB2 = #{locations(:albion).name}")
  end

  def test_includes_the_projects_user_aliases
    text = prompt
    fixture = project_aliases(:one) # "RS" -> rolf

    assert_includes(text, "#{fixture.name} = ")
  end

  # The user table is a reading aid, not a substitution rule. Expanding
  # "dcs" to "Dorothy Smullen" destroys the value: the initials resolve
  # to a User two ways, the expanded display name resolves neither.
  def test_asks_for_initials_verbatim_not_expanded
    text = prompt

    assert_match(/Return what is WRITTEN/, text)
    assert_no_match(/Expand an entry/, text)
  end

  # An abbreviation the project hasn't defined must come back verbatim
  # rather than guessed at -- that is what surfaces it for an admin to
  # add, instead of silently resolving to a plausible wrong site.
  def test_instructs_verbatim_return_for_unknown_abbreviations
    ProjectAlias.create!(project: @project, name: "EB2",
                         target: locations(:albion))

    assert_includes(prompt, "verbatim")
  end

  def test_includes_the_events_date_range
    @project.update!(start_date: Date.parse("2026-07-30"),
                     end_date: Date.parse("2026-08-02"))

    text = prompt

    assert_includes(text, "2026-07-30")
    assert_includes(text, "2026-08-02")
  end

  def test_still_asks_for_iso_dates_without_a_range
    @project.update_columns(start_date: nil, end_date: nil)

    assert_includes(prompt, "YYYY-MM-DD")
  end

  # The MycoMap voucher is printed, not handwritten, and belongs in its
  # own field -- left unsaid, the model files it under Other Codes.
  def test_separates_the_printed_voucher_from_other_codes
    text = prompt

    assert_includes(text, "MycoMap Voucher Number")
    assert_includes(text, "Other Codes")
    assert_match(/printed/i, text)
  end

  def test_tells_the_model_not_to_identify_the_mushroom
    assert_match(/do not identify/i, prompt)
  end

  # No project, no aliases: the prompt still has to be usable.
  def test_survives_an_observation_with_no_project
    @project.observations.delete(@obs)

    text = prompt(@obs.reload)

    assert_includes(text, "Field Slip Code")
    assert_includes(text, "YYYY-MM-DD")
  end

  def test_uses_the_attached_slip_code_as_the_example
    assert_includes(prompt, @obs.field_slip.code) if @obs.field_slip
  end

  # A foray can define more aliases than belong in one prompt; the cap
  # keeps the request bounded rather than growing without limit.
  def test_alias_list_is_capped
    max = FieldSlip::Extractor::Prompt::MAX_ALIASES
    (max + 5).times do |i|
      ProjectAlias.create!(project: @project, name: "L#{i}",
                           target: locations(:albion))
    end

    rows = prompt.scan(/^  L\d+ = /).size

    assert_operator(rows, :<=, max)
  end
end
