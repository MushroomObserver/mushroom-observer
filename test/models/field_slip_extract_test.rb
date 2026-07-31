# frozen_string_literal: true

require("test_helper")

class FieldSlipExtractTest < UnitTestCase
  def setup
    @obs = observations(:minimal_unknown_obs)
    @image = images(:in_situ_image)
    @obs.images << @image unless @obs.images.include?(@image)
  end

  def result(fields: {}, confidence: {}, provider: "gemini", model: "m")
    FieldSlip::Extractor::Result.new(
      provider: provider, model: model, raw: { "ok" => true },
      fields: fields, confidence: confidence
    )
  end

  def record(fields: {}, confidence: {}, **)
    FieldSlipExtract.record(image: @image, user: rolf, prompt_version: "1",
                            result: result(fields:, confidence:, **))
  end

  # One row per image: pressing the button again replaces the previous
  # read rather than accumulating versions nobody reviews.
  def test_record_replaces_rather_than_accumulates
    first = record(fields: { "Collector" => "A" })
    second = record(fields: { "Collector" => "B" })

    assert_equal(first.id, second.id)
    assert_equal(1, FieldSlipExtract.where(image_id: @image.id).count)
    assert_equal("B", second.value_for("Collector"))
  end

  def test_record_stores_provenance_and_raw_response
    extract = record(fields: { "Collector" => "A" }, model: "gemini-3.6-flash")

    assert_equal("gemini", extract.provider)
    assert_equal("gemini-3.6-flash", extract.model)
    assert_equal("1", extract.prompt_version)
    assert_equal({ "ok" => true }, extract.data["raw"])
  end

  def test_confidence_defaults_to_low_when_unusable
    extract = record(fields: { "Collector" => "A" },
                     confidence: { "Collector" => "wildly sure" })

    assert_equal("low", extract.confidence_for("Collector"))
    assert_equal("low", extract.confidence_for("Date"), "absent -> low")
  end

  def test_confidence_passes_through_known_levels
    extract = record(fields: { "Date" => "2026-07-30" },
                     confidence: { "Date" => "HIGH" })

    assert_equal("high", extract.confidence_for("Date"))
  end

  # An extract describes one image, so it goes when the image does
  # rather than lingering as an orphan for the integrity job to sweep.
  def test_destroyed_with_its_image
    record(fields: { "Collector" => "A" })
    image = Image.find(@image.id)
    image.current_user = image.user

    assert_difference("FieldSlipExtract.count", -1) { image.destroy }
  end

  # ---------- code mismatch ----------

  def test_code_mismatch_nil_when_codes_agree
    slip = FieldSlip.create!(code: "NEMF-10222", user: @obs.user)
    attach_slip(slip)
    extract = record(fields: { "Field Slip Code" => "NEMF-10222" })

    assert_nil(extract.code_mismatch)
  end

  # The strongest signal that this photo is not this observation's slip.
  def test_code_mismatch_reports_both_codes
    slip = FieldSlip.create!(code: "NEMF-10222", user: @obs.user)
    attach_slip(slip)
    extract = record(fields: { "Field Slip Code" => "NEMF-99999" })

    assert_equal(%w[NEMF-99999 NEMF-10222], extract.code_mismatch)
  end

  def test_code_mismatch_nil_without_an_attached_slip
    @obs.update!(occurrence: nil)

    assert_nil(@obs.reload.field_slip, "premise: no slip attached")
    extract = record(fields: { "Field Slip Code" => "NEMF-99999" })

    assert_nil(extract.code_mismatch)
  end

  def test_code_mismatch_nil_when_nothing_was_read
    slip = FieldSlip.create!(code: "NEMF-10222", user: @obs.user)
    attach_slip(slip)

    assert_nil(record(fields: { "Field Slip Code" => "" }).code_mismatch)
  end

  # ---------- unknown location alias ----------

  # "EB2" for "Early Bird 2" where the project only defines "2": naming
  # it is what lets an admin add the alias, which then improves every
  # later slip, since the prompt is built from the same table.
  def test_unknown_location_alias_names_an_undefined_abbreviation
    extract = record(fields: { "Location" => "EB2" })

    assert_equal("EB2", extract.unknown_location_alias)
  end

  def test_unknown_location_alias_nil_when_the_project_defines_it
    project = projects(:eol_project)
    project.observations << @obs unless project.observations.include?(@obs)
    ProjectAlias.create!(project: project, name: "Walk 9",
                         target: locations(:albion))
    extract = record(fields: { "Location" => "Walk 9" })

    assert_nil(extract.reload.unknown_location_alias)
  end

  def test_unknown_location_alias_nil_when_it_matches_the_location
    extract = record(fields: { "Location" => @obs.location.name })

    assert_nil(extract.unknown_location_alias)
  end

  def test_unknown_location_alias_nil_when_nothing_was_read
    assert_nil(record(fields: {}).unknown_location_alias)
  end

  # A full MO location name is not an unknown abbreviation, alias or no
  # alias -- warning about one would tell the reviewer that something MO
  # already knows is unrecognized, and offer to define an alias for it.
  def test_unknown_location_alias_nil_for_a_real_location_name
    other = locations(:albion)

    assert_not_equal(other, @obs.location, "premise: not this obs's location")
    assert_nil(record(fields: { "Location" => other.name }).
               unknown_location_alias)
  end

  # ---------- location suggestion ----------

  # "Fulton, Co" against a project already sitting in "Fulton Co.,
  # Pennsylvania, USA": punctuation and case differ, the words do not.
  def test_suggests_a_location_the_project_already_uses
    target = project_using(locations(:albion))
    written = target.name.split(",").first.downcase

    extract = record(fields: { "Location" => written })

    assert_equal(target, extract.location_suggestion)
  end

  def test_no_suggestion_when_nothing_matches
    project_using(locations(:albion))

    assert_nil(record(fields: { "Location" => "Zzz" }).location_suggestion)
  end

  # A guess must not pick between two plausible sites, so an ambiguous
  # abbreviation suggests nothing at all. "Albion" prefixes both
  # "Albion, California, USA" and the twin created here.
  def test_no_suggestion_when_several_match
    albion = locations(:albion)
    project_using(albion)
    add_to_project(observations(:coprinus_comatus_obs), twin_of(albion))
    written = albion.name.split(",").first

    assert_nil(record(fields: { "Location" => written }).location_suggestion)
  end

  # A full name still resolves when a longer sibling exists, because
  # matching is a prefix test on the CANDIDATE: "Albion, California,
  # USA" is not a prefix of "Albion Annex, California, USA".
  def test_a_full_name_resolves_despite_a_longer_sibling
    albion = locations(:albion)
    project_using(albion)
    add_to_project(observations(:coprinus_comatus_obs), twin_of(albion))

    assert_equal(albion,
                 record(fields: { "Location" => albion.name }).
                 location_suggestion)
  end

  def test_no_suggestion_without_a_project
    assert_nil(record(fields: { "Location" => "Anything" }).
               location_suggestion)
  end

  def test_no_suggestion_when_nothing_was_read
    project_using(locations(:albion))

    assert_nil(record(fields: {}).location_suggestion)
  end

  # ---------- permitted? ----------

  def test_permitted_for_site_admin
    assert(FieldSlipExtract.permitted?(image: @image, user: dick,
                                       site_admin: true))
  end

  # A foray's own organizers are the people who can tell whether a slip
  # was transcribed right, so project admins get in too.
  def test_permitted_for_admin_of_the_observations_project
    project = projects(:eol_project)
    project.observations << @obs unless project.observations.include?(@obs)

    assert(project.is_admin?(rolf), "fixture must have rolf as admin")
    assert(FieldSlipExtract.permitted?(image: @image.reload, user: rolf))
  end

  def test_not_permitted_for_a_plain_member
    project = projects(:eol_project)
    project.observations << @obs unless project.observations.include?(@obs)

    assert_not(project.is_admin?(katrina))
    assert_not(FieldSlipExtract.permitted?(image: @image.reload,
                                           user: katrina))
  end

  # An image can carry several observations, and permission is granted
  # by ANY of them -- `in_situ_image` also belongs to an observation in
  # the Bolete Project, which is why the stranger here has to be someone
  # who administers none of them.
  def test_not_permitted_for_a_stranger
    stranger = katrina
    admin_of = @image.reload.observations.flat_map(&:projects).
               select { |project| project.is_admin?(stranger) }

    assert_empty(admin_of, "premise: stranger administers none of them")
    assert_not(FieldSlipExtract.permitted?(image: @image, user: stranger))
  end

  def test_not_permitted_without_a_user_even_in_admin_mode
    assert_not(FieldSlipExtract.permitted?(image: @image, user: nil,
                                           site_admin: true))
  end

  # Permission comes from any of the image's observations, not only the
  # one the review would write to.
  def test_permitted_via_a_second_observation_on_the_same_image
    other = @image.observations.find { |obs| obs.id != @obs.id }

    assert(other, "premise: the image carries a second observation")
    assert(other.projects.any? { |project| project.is_admin?(dick) })
    assert(FieldSlipExtract.permitted?(image: @image, user: dick))
  end

  private

  # Puts a second observation in the project at a known location, so a
  # suggestion has something to match against.
  def project_using(location)
    project = projects(:eol_project)
    project.observations << @obs unless project.observations.include?(@obs)
    other = observations(:detailed_unknown_obs)
    project.observations << other unless project.observations.include?(other)
    other.update!(location: location)
    location
  end

  def add_to_project(obs, location)
    project = projects(:eol_project)
    project.observations << obs unless project.observations.include?(obs)
    obs.update!(location: location)
    location
  end

  # A second Location whose name starts with the first's, so a written
  # abbreviation matches both.
  def twin_of(location)
    head, tail = location.name.split(",", 2)
    twin = Location.new(user: rolf, name: "#{head} Annex,#{tail}",
                        north: location.north, south: location.south,
                        east: location.east, west: location.west)
    twin.current_user = rolf
    twin.save!
    twin
  end

  def attach_slip(slip)
    occ = Occurrence.create!(user: @obs.user, primary_observation: @obs,
                             field_slip: slip)
    @obs.update!(occurrence: occ)
  end
end
