# frozen_string_literal: true

require("test_helper")

class FormObject::FieldSlipReviewTest < UnitTestCase
  def setup
    @obs = observations(:minimal_unknown_obs)
    @image = images(:in_situ_image)
    @obs.images << @image unless @obs.images.include?(@image)
  end

  def build(fields: {}, confidence: {}, user: rolf, template: "mo")
    extract = FieldSlipExtract.record(
      image: @image, user: rolf, prompt_version: "1",
      result: FieldSlip::Extractor::Result.new(
        provider: "g", model: "m", raw: {}, fields: fields,
        confidence: confidence, template: template
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

    assert_equal(FieldSlip::Template.for(:mo).fields.keys,
                 review.rows.map(&:field))
  end

  # Nothing read means nothing to review, so the table stays short.
  def test_rows_to_show_drops_blank_rows
    review = build(fields: { "Collector" => "Scott Shapiro" })

    assert_equal(["Collector"], review.rows_to_show.map(&:field))
  end

  # The ID needs a real label to render its autocompleter, which a table
  # cell has no room for, so it is pulled out of the table.
  def test_rows_to_show_excludes_the_name_row
    review = build(fields: { "ID" => "Boletus",
                             "Collector" => "Scott Shapiro" })

    assert_not_includes(review.rows_to_show.map(&:field),
                        "ID")
    assert_equal("ID", review.name_row.field)
  end

  def test_name_row_is_editable_but_not_savable
    review = build(fields: { "ID" => "Boletus" })
    row = review.name_row

    assert(row.editable, "the reviewer looks the real name up here")
    assert_not(row.savable, "it becomes a naming, not an attribute")
  end

  # A linked observation has nothing to attach, so the code stays a
  # cross-check.
  def test_code_row_is_review_only_when_the_observation_has_a_slip
    assert_not_nil(@obs.occurrence_id, "premise: fixture is slip-linked")

    review = build(fields: { "Field Slip Code" => "NEMF-10222" })
    row = row_for(review, "Field Slip Code")

    assert_not(row.editable)
    assert_not(row.savable)
  end

  # A slip-less observation's code row becomes the attach control: the
  # background job usually attached already, so reaching review without
  # a slip means a case needing human judgment.
  def test_code_row_attaches_when_the_observation_has_no_slip
    @obs.update!(occurrence: nil)

    review = build(fields: { "Field Slip Code" => "NEMF-10222" })
    row = row_for(review, "Field Slip Code")

    assert(row.code_row?)
    assert(row.editable, "a misread code gets corrected here")
    assert(row.savable)
    assert(row.default_use?)
  end

  def test_code_row_stays_review_only_when_nothing_was_read
    @obs.update!(occurrence: nil)

    review = build(fields: { "Collector" => "A" })

    assert_not(row_for(review, "Field Slip Code").savable)
  end

  # The observation has its own occurrence (e.g. a reflection paired
  # with its Edit-companion), and the read code names a slip on a
  # different one: the code row is savable so the reviewer can merge
  # the two (#4214).
  def test_code_row_savable_to_merge_a_different_slip_occurrence
    @obs.update!(occurrence: nil)
    own = Occurrence.create!(user: @obs.user, primary_observation: @obs)
    @obs.update!(occurrence: own)
    slip_obs = observations(:coprinus_comatus_obs)
    slip = FieldSlip.find_or_create_by_code("NEMF-10333", slip_obs.user)
    slip_obs.update!(occurrence: nil)
    slip_obs.field_slip = slip
    slip_obs.save!

    review = build(fields: { "Field Slip Code" => "NEMF-10333" })
    row = row_for(review, "Field Slip Code")

    assert(row.savable)
    assert(row.default_use?)
  end

  # The read code names the slip already on the observation's own
  # occurrence -- applying it would do nothing, so no tick is offered.
  def test_code_row_review_only_when_its_own_occurrence_holds_the_slip
    @obs.update!(occurrence: nil)
    slip = FieldSlip.find_or_create_by_code("NEMF-10444", @obs.user)
    @obs.field_slip = slip
    @obs.save!

    review = build(fields: { "Field Slip Code" => "NEMF-10444" })

    assert_not(row_for(review, "Field Slip Code").savable)
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

  # Marked, but still ticked -- see `Row#default_use?`.
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
    review = build(fields: { "ID" =>
                             "Coprinus comatus" })

    assert(review.name_known)
  end

  def test_name_not_known_for_a_common_name
    review = build(fields: { "ID" =>
                             "Lumpy Bracket" })

    assert_not(review.name_known)
  end

  def test_name_not_known_when_blank_or_userless
    assert_not(build(fields: {}).name_known)
    assert_not(build(fields: { "ID" => "Boletus" },
                     user: nil).name_known,
               "no user means no resolver, so no default tick")
  end

  def test_confidence_rides_along_on_the_row
    review = build(fields: { "Date" => "2026-07-30" },
                   confidence: { "Date" => "low" })

    assert_equal("low", row_for(review, "Date").confidence)
  end

  # ---------- iNat flag ----------

  def test_inat_code_detected_in_a_numeric_other_codes
    assert(build(fields: { "Other Codes" => "386717373" }).inat_code)
    assert_not(build(fields: { "Other Codes" => "DBG-123" }).inat_code)
  end

  def test_inat_flag_rides_on_the_templates_own_field
    assert(row_for(build(fields: { "Other Codes" => "1" }),
                   "Other Codes").inat_row?)
  end

  # ---------- DBG template ----------

  # The rows follow the extract's own template, and the special rows
  # (name, location, iNat) follow its labels.
  def test_dbg_extract_builds_dbg_rows
    review = build(template: "dbg",
                   fields: { "Species" => "Thelephora",
                             "Location/Foray" => "Crags Creek Trailhead",
                             "iNaturalist" => "10:29 388879492" })

    assert_equal(FieldSlip::Template.for(:dbg).fields.keys,
                 review.rows.map(&:field))
    assert_equal("Species", review.name_row.field)
    assert_equal("Location/Foray", review.location_row.field)
    assert(row_for(review, "iNaturalist").inat_row?)
    assert(review.inat_code,
           "the id counts even mixed with a timestamp")
  end

  def test_dbg_name_known_reads_the_species_field
    review = build(template: "dbg",
                   fields: { "Species" => "Coprinus comatus" })

    assert(review.name_known)
  end
end
