# frozen_string_literal: true

require("test_helper")

class FormObject::FieldSlipReviewTest < UnitTestCase
  def setup
    @obs = observations(:minimal_unknown_obs)
    @image = images(:in_situ_image)
    @obs.images << @image unless @obs.images.include?(@image)
  end

  def build(fields: {}, confidence: {}, user: rolf)
    extract = FieldSlipExtract.record(
      image: @image, user: rolf, prompt_version: "1",
      result: FieldSlip::Extractor::Result.new(
        provider: "g", model: "m", raw: {}, fields: fields,
        confidence: confidence
      )
    )
    FormObject::FieldSlipReview.build(extract: extract, observation: @obs,
                                      user: user)
  end

  def row_for(review, field)
    review.rows.find { |row| row.field == field }
  end

  def test_builds_one_row_per_field
    review = build

    assert_equal(FieldSlip::Extractor::FIELDS.keys, review.rows.map(&:field))
  end

  # Nothing read means nothing to review, so the table stays short.
  def test_rows_to_show_drops_blank_rows
    review = build(fields: { "Collector" => "Scott Shapiro" })

    assert_equal(["Collector"], review.rows_to_show.map(&:field))
  end

  # The ID needs a real label to render its autocompleter, which a table
  # cell has no room for, so it is pulled out of the table.
  def test_rows_to_show_excludes_the_name_row
    review = build(fields: { FieldSlip::Extractor::NAME_FIELD => "Boletus",
                             "Collector" => "Scott Shapiro" })

    assert_not_includes(review.rows_to_show.map(&:field),
                        FieldSlip::Extractor::NAME_FIELD)
    assert_equal(FieldSlip::Extractor::NAME_FIELD, review.name_row.field)
  end

  def test_name_row_is_editable_but_not_savable
    review = build(fields: { FieldSlip::Extractor::NAME_FIELD => "Boletus" })
    row = review.name_row

    assert(row.editable, "the reviewer looks the real name up here")
    assert_not(row.savable, "it becomes a naming, not an attribute")
  end

  def test_review_only_rows_are_neither_editable_nor_savable
    review = build(fields: { "Field Slip Code" => "NEMF-10222" })
    row = row_for(review, "Field Slip Code")

    assert_not(row.editable)
    assert_not(row.savable)
  end

  # ---------- current values ----------

  def test_current_value_reads_a_column
    @obs.update!(collector: "Someone Else")
    review = build(fields: { "Collector" => "Scott Shapiro" })

    assert_equal("Someone Else", row_for(review, "Collector").current)
  end

  def test_current_value_reads_a_notes_key
    @obs.update!(notes: { Substrate: "soil" })
    review = build(fields: { "Substrate" => "wood" })

    assert_equal("soil", row_for(review, "Substrate").current)
  end

  # Locality is stored as `where`, whatever the form calls it.
  def test_current_value_for_locality_reads_where
    review = build(fields: { "Location" => "EB2" })

    assert_equal(@obs.where, row_for(review, "Location").current)
  end

  # ---------- conflict and the tick default ----------

  # A conflict is marked in the table but still ticks: on the
  # observations this exists for, the "existing" value is the form's own
  # default rather than anything a person chose.
  def test_conflict_is_flagged_but_still_ticks
    @obs.update!(collector: "Someone Else")
    row = row_for(build(fields: { "Collector" => "Scott Shapiro" }),
                  "Collector")

    assert_predicate(row, :conflict?)
    assert(row.default_use?)
  end

  def test_no_conflict_when_the_observation_is_empty
    @obs.update!(collector: nil)
    row = row_for(build(fields: { "Collector" => "Scott Shapiro" }),
                  "Collector")

    assert_not_predicate(row, :conflict?)
    assert(row.default_use?, "nothing to lose, so it ticks")
  end

  def test_no_conflict_when_the_values_agree
    @obs.update!(collector: "Scott Shapiro")
    row = row_for(build(fields: { "Collector" => " Scott Shapiro " }),
                  "Collector")

    assert_not_predicate(row, :conflict?)
  end

  def test_blank_rows_never_tick
    row = row_for(build(fields: { "Collector" => "" }), "Collector")

    assert_not(row.default_use?)
  end

  # ---------- name_known ----------

  # Ticked by default only when saving would succeed without a
  # create-the-name round-trip.
  def test_name_known_for_a_name_mo_holds
    review = build(fields: { FieldSlip::Extractor::NAME_FIELD =>
                             "Coprinus comatus" })

    assert(review.name_known)
  end

  def test_name_not_known_for_a_common_name
    review = build(fields: { FieldSlip::Extractor::NAME_FIELD =>
                             "Lumpy Bracket" })

    assert_not(review.name_known)
  end

  def test_name_not_known_when_blank_or_userless
    assert_not(build(fields: {}).name_known)
    assert_not(build(fields: { FieldSlip::Extractor::NAME_FIELD => "Boletus" },
                     user: nil).name_known,
               "no user means no resolver, so no default tick")
  end

  def test_confidence_rides_along_on_the_row
    review = build(fields: { "Date" => "2026-07-30" },
                   confidence: { "Date" => "low" })

    assert_equal("low", row_for(review, "Date").confidence)
  end
end
