# frozen_string_literal: true

require("test_helper")

class SourceTest < UnitTestCase
  def test_inaturalist_lookup
    inat = Source.inaturalist
    assert_equal("iNaturalist", inat.name)
    assert_equal(sources(:inaturalist), inat)
  end

  def test_validations
    src = Source.new
    assert_not(src.valid?)
    assert_not_empty(src.errors[:name])

    too_long = Source.new(name: "a" * 101)
    too_long.valid?
    assert_not_empty(too_long.errors[:name])

    long_url = Source.new(name: "ok", url: "u" * 1025)
    long_url.valid?
    assert_not_empty(long_url.errors[:url])
  end

  def test_name_unique_case_insensitive
    Source.create!(name: "ExampleSource")
    dup = Source.new(name: "examplesource")
    assert_not(dup.valid?)
    assert_not_empty(dup.errors[:name])
  end

  def test_observations_association
    inat = sources(:inaturalist)
    obs = observations(:imported_inat_obs)
    assert_includes(inat.observations, obs)
    assert_equal(inat, obs.external_source)
  end

  def test_destroy_blocked_when_observations_exist
    inat = sources(:inaturalist)
    assert_raises(ActiveRecord::DeleteRestrictionError) do
      inat.destroy!
    end
  end
end
