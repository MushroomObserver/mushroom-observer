# frozen_string_literal: true

require("test_helper")

class FieldSlip::Extractor::ApplierTest < UnitTestCase
  def setup
    @obs = observations(:minimal_unknown_obs)
    @project = projects(:eol_project)
    @project.observations << @obs unless @project.observations.include?(@obs)
  end

  def apply_fields(chosen, user: rolf, inat_code: false, template: :mo)
    FieldSlip::Extractor::Applier.new(
      observation: @obs, chosen: chosen, user: user,
      template: FieldSlip::Template.for(template), inat_code: inat_code
    ).apply
    @obs.reload
  end

  def test_applies_only_what_was_chosen
    was = @obs.when
    apply_fields({ "Collector" => "Scott Shapiro" })

    assert_equal("Scott Shapiro", @obs.collector)
    assert_equal(was, @obs.when, "an unchosen field is left alone")
  end

  def test_writes_notes_fields_under_their_keys
    apply_fields({ "Substrate" => "wood",
                   "MycoMap Voucher Number" => "N26-0290" })

    assert_equal("wood", @obs.notes[:Substrate])
    assert_equal("N26-0290", @obs.notes[:MycoMap_Voucher_Number])
  end

  # Several notes fields in one pass have to merge, not overwrite each
  # other -- and must not drop notes the observation already had.
  def test_notes_writes_merge_with_existing_notes
    @obs.update!(notes: { Other: "keep me" })
    apply_fields({ "Substrate" => "wood", "Habit" => "clustered" })

    assert_equal("keep me", @obs.notes[:Other])
    assert_equal("wood", @obs.notes[:Substrate])
    assert_equal("clustered", @obs.notes[:Habit])
  end

  def test_parses_a_date
    apply_fields({ "Date" => "2026-07-30" })

    assert_equal(Date.parse("2026-07-30"), @obs.when)
  end

  # Prose dates are skipped, not guessed at: `Date.parse` would read
  # "sometime in July" as July 1st of the current year without
  # complaint, silently setting a wrong date.
  def test_unparseable_date_is_skipped_not_fatal
    was = @obs.when
    apply_fields({ "Date" => "sometime in July",
                   "Collector" => "Scott Shapiro" })

    assert_equal(was, @obs.when)
    assert_equal("Scott Shapiro", @obs.collector)
  end

  # "Id by" names a person, and MO stores that as a textile user link,
  # not bare text -- the same shape the observation form writes, so an
  # observation reads back the same whichever route entered it.
  def test_id_by_resolves_a_project_alias_to_a_user_link
    fixture = project_aliases(:one) # "RS" -> rolf

    apply_fields({ "ID By" => fixture.name })

    assert_equal(rolf.textile_name, @obs.notes[:Field_Slip_ID_By])
  end

  def test_id_by_resolves_a_login
    apply_fields({ "ID By" => rolf.login })

    assert_equal(rolf.textile_name, @obs.notes[:Field_Slip_ID_By])
  end

  # Whoever identified a collection is not always an MO user.
  def test_id_by_keeps_unmatched_text_verbatim
    apply_fields({ "ID By" => "Some Visiting Expert" })

    assert_equal("Some Visiting Expert", @obs.notes[:Field_Slip_ID_By])
  end

  # A collector naming a project alias resolves to that user, so the
  # observation gets the link rather than initials as free text.
  def test_collector_resolves_through_a_project_alias
    fixture = project_aliases(:one) # "RS" -> rolf

    apply_fields({ "Collector" => fixture.name })

    assert_equal(rolf.id, @obs.collector_user_id)
  end

  def test_collector_left_as_text_when_no_alias_matches
    apply_fields({ "Collector" => "Some Stranger" })

    assert_equal("Some Stranger", @obs.collector)
    assert_nil(@obs.collector_user_id)
  end

  def test_location_resolves_through_a_project_alias
    ProjectAlias.create!(project: @project, name: "EB2",
                         target: locations(:albion))

    apply_fields({ "Location" => "EB2" })

    assert_equal(locations(:albion), @obs.location)
    assert_equal(locations(:albion).name, @obs.where)
  end

  def test_location_resolves_a_real_location_name
    apply_fields({ "Location" => locations(:burbank).name })

    assert_equal(locations(:burbank), @obs.location)
  end

  # An unrecognized locality is kept as written rather than dropped: the
  # observation form does the same, and a human can fix it later.
  def test_unknown_location_is_kept_as_free_text
    apply_fields({ "Location" => "Behind the barn" })

    assert_nil(@obs.location)
    assert_equal("Behind the barn", @obs.where)
  end

  # A numeric "Other Codes" is an iNat observation id in practice, and
  # is stored as the link the field slip form writes, so an observation
  # reads back the same whichever route entered it.
  def test_numeric_other_codes_stored_as_an_inat_link
    apply_fields({ "Other Codes" => "386717373" }, inat_code: true)

    assert_equal(FieldSlipNotesBuilder.inat_link("386717373"),
                 @obs.notes[:Other_Codes])
  end

  def test_other_codes_left_bare_when_not_flagged
    apply_fields({ "Other Codes" => "386717373" })

    assert_equal("386717373", @obs.notes[:Other_Codes])
  end

  # Editing a value that is already a link must not nest one link in
  # another.
  def test_an_existing_inat_link_is_not_wrapped_twice
    already = FieldSlipNotesBuilder.inat_link("386717373")

    apply_fields({ "Other Codes" => already }, inat_code: true)

    assert_equal(already, @obs.notes[:Other_Codes])
  end

  # The flag is specific to Other Codes; a numeric value elsewhere is
  # just a value.
  def test_the_inat_flag_does_not_touch_other_fields
    apply_fields({ "MycoMap Voucher Number" => "12345" }, inat_code: true)

    assert_equal("12345", @obs.notes[:MycoMap_Voucher_Number])
  end

  def test_blank_values_are_not_applied
    was = @obs.collector
    apply_fields({ "Collector" => "   " })

    assert_equal_even_if_nil(was, @obs.collector)
  end

  # The two review-only fields have no target, so they can never be
  # written even if they arrive in the chosen set.
  def test_review_only_fields_are_never_written
    namings_before = @obs.namings.count
    slip_before = @obs.field_slip&.code

    apply_fields({ "Field Slip Code" => "NEMF-99999",
                   "ID" => "Coprinus comatus" })

    assert_equal_even_if_nil(slip_before, @obs.field_slip&.code)
    assert_equal(namings_before, @obs.namings.count,
                 "the ID is proposed elsewhere, never applied here")
  end

  def test_nothing_chosen_leaves_the_observation_alone
    before = @obs.attributes.dup
    apply_fields({})

    assert_equal_even_if_nil(before["collector"], @obs.collector)
    assert_equal(before["when"], @obs.when)
  end

  # ---------- DBG template ----------

  def test_dbg_fields_land_under_their_own_notes_keys
    apply_fields({ "Plants" => "Spruce",
                   "Voucher Number" => "CO26-0290",
                   "ID Date" => "8/7" }, template: :dbg)

    assert_equal("Spruce", @obs.notes[:Plants])
    assert_equal("CO26-0290", @obs.notes[:Voucher_Number])
    assert_equal("8/7", @obs.notes[:Field_Slip_ID_Date])
  end

  def test_dbg_coordinates_are_applied_as_a_pair
    apply_fields({ "Latitude" => "38.8703",
                   "Longitude" => "-105.0442" }, template: :dbg)

    assert_in_delta(38.8703, @obs.lat)
    assert_in_delta(-105.0442, @obs.lng)
  end

  # Observation validates lat/lng as a pair; half a pair must not sink
  # the rest of the save.
  def test_dbg_a_lone_coordinate_is_dropped_not_fatal
    apply_fields({ "Latitude" => "38.8703",
                   "Collector" => "A. W. Wilson" }, template: :dbg)

    assert_nil(@obs.lat)
    assert_equal("A. W. Wilson", @obs.collector)
  end

  def test_dbg_unparseable_coordinates_are_skipped
    apply_fields({ "Latitude" => "somewhere",
                   "Longitude" => "-105.0442" }, template: :dbg)

    assert_nil(@obs.lat)
    assert_nil(@obs.lng)
  end

  # The iNaturalist box often holds a timestamp beside the id ("10:29
  # 388879492"); the id becomes the link and the rest is kept beside
  # it as a checksum against the iNat record.
  def test_dbg_inat_box_with_timestamp_links_the_id
    apply_fields({ "iNaturalist" => "10:29 388879492" },
                 template: :dbg, inat_code: true)

    link = FieldSlipNotesBuilder.inat_link("388879492")

    assert_equal("#{link} (10:29)", @obs.notes[:iNaturalist])
  end

  def test_dbg_bare_inat_number_links_without_leftover
    apply_fields({ "iNaturalist" => "388879863" },
                 template: :dbg, inat_code: true)

    assert_equal(FieldSlipNotesBuilder.inat_link("388879863"),
                 @obs.notes[:iNaturalist])
  end

  # Flagged but holding no id -- a username and clock time only -- the
  # entry stays as written rather than becoming a broken link.
  def test_dbg_inat_box_without_an_id_left_bare
    apply_fields({ "iNaturalist" => "someuser 10:29" },
                 template: :dbg, inat_code: true)

    assert_equal("someuser 10:29", @obs.notes[:iNaturalist])
  end

  def test_dbg_location_foray_resolves_through_a_project_alias
    ProjectAlias.create!(project: @project, name: "Crags Creek #2",
                         target: locations(:albion))

    apply_fields({ "Location/Foray" => "Crags Creek #2" }, template: :dbg)

    assert_equal(locations(:albion), @obs.location)
  end

  # State and County are components of the reviewed place name, never
  # stored on their own.
  def test_dbg_state_and_county_are_review_only
    apply_fields({ "State" => "CO", "County" => "Teller" }, template: :dbg)

    assert_empty(@obs.notes.to_h.values & %w[CO Teller])
  end
end
