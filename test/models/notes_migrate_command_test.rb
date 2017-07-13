# TODO - delete this file after production db is migrated and
# and we are totally ok with it
require "test_helper"

# test the up and down migration statements for observation.notes format
class NotesMigrateCommandTest < UnitTestCase
  # temporary test of commands to up-migrate notes format to YAML
  # and down-migrate back to original
  def test_up_and_down
    # Modify notes of some fixtures
    # I don't want to put all this junk into the fixtures because it will
    # have to be removed after up-migration

    # Give some of them complicated pre-migration notes
    observations(:vouchered_obs).notes = "_Agaricus_ but what species?  I was going to guess _A. subrutilescens_, but then noticed that cap flesh stains yellow near cuticle when cut.  Both Arora and Trudell & Ammirati say that _A. subrutilescens_,is non-staining.
In duff (and possibly bark dust).  Nearest tree was a spruce.
I do not have a mature specimen, so cannot tell real maximum sizes and other characters.
Cap
* appears brown from a distance, but actually white, with abundant brown fibrils
* max diameter 6.5 cm
* mild almond odor and taste
* flesh white, 1 cm thick
* cap flesh stains yellow near cuticle when cut.  See 3rd photo.
Gills
* free
* close
* young gills off-white
* 6mm
Stipe
* shaggy white starting at partial veil downward for about 1/2 length of stipe, then brown fibrils
* almost all the stipe was below the duff; only the cap was showing.  See 2nd photo
* 17.5 cm long
* 2.5 cm thick
* slightly bulbous base
* almond taste
* hollow
* membranous partial veil still present in all specimens, so I cannot be certain what annulus will look like.  But by how it's attached to the stipe, I'm guessing it will be skirt-like
* stipe does not stain on cutting or bruising
    "
    observations(:vouchered_obs).save

    observations(:vouchered_imged_obs).notes = %{
+Collectors+: Sally Visher, Joseph D. Cohen
+Substrate+: Soil
+Habitat+:  below undergrowth in relatively open area in coastal "??Picea sitchensis??":http://eol.org/pages/1033696 (Sitka Spruce) forest.
+Nearest large tree+:  "??Picea sitchensis??":http://eol.org/pages/1033696 (Sitka Spruce).  (No other conifer species anywhere near collection.)
+Chemical+: Cap cuticle may stain dark red in KOH; it's hard to tell because of the age and water-logged state of this mushroom. Cap flesh negative in KOH.
+Spores+: Brown
bq. +Measurements+:
Piximètre 5.9 R 1530 : le 20/06/2017 à 16:55:06.1172147
(12.4) 12.5 - 14.5 (15.8) × (4.9) 5.8 - 6.7 (6.8) µm
Q = 2 - 2.3 (2.7) ; N = 10
**Me = 13.6 × 6.2 µm ; Qe = 2.2**
+Other+:  The blue staining seen in some photos appears to originate in the cap flesh around its edges.  The final 3 macro photos (with white background) were taken ~2.5 hours after collecting this mushroom.}
    observations(:vouchered_imged_obs).save

    observations(:updated_2013_obs).notes = %{ Used “North American Boletes” by Bessette and Roody for ID.
[admin – Sat Aug 14 02:00:21 +0000 2010]: Changed location name from ‘Fairfield, Ct.’ to ‘Fairfield, Connecticut, USA’}
    observations(:updated_2013_obs).save

    # make pre-migration notes blank
    blank_notes_obs = observations(:minimal_unknown_obs)
    blank_notes_obs.notes = ""
    blank_notes_obs.save

    # make pre-migration notes nil
    nil_notes_obs = observations(:unlisted_rolf_obs)
    nil_notes_obs.notes = nil
    nil_notes_obs.save

    observations     = Observation.all
    original_notes   = observations.map(&:notes)
    original_updated = observations.map(&:updated_at)

    #### Prove that up method works ###
    up

    # Up migrated notes should be translatable to original
    observations.size.times do |i|
      up_notes = observations[i].reload.notes
      if original_notes[i].empty?
        assert_nil(up_notes,
                   "Obs #{observations[i].id} up notes should be nil")
        assert_nil(to_down_notes(up_notes),
                   "Obs #{observations[i].id} nil up notes not convertible")
      else
        assert_equal(
          original_notes[i], to_down_notes(up_notes),
          "Obs #{observations[i].id} up notes not convertible"
        )
      end
    end

    # Prove notes which were originally empty notes were up-migrated to nil
    assert_nil(blank_notes_obs.reload.notes)

    # Prove notes which were originally nil are still nil
    assert_nil(nil_notes_obs.reload.notes)

    #### prove that down method works ###
    # It should restore everything except those which were originally ""
    # because both "" and nil were up-migrated to nil.
    # So after up-mgration there's no way to differentiate them.
    # Both will be down-migrated to nil.
    down

    observations.size.times do |i|
      obs = observations[i]
      if original_notes[i].empty?
        assert_nil(obs.reload.notes)
      else
        assert_equal(original_notes[i], obs.reload.notes)
      end
    end
  end

  ##########################################################################
  # remainder of this file is what gets moved to the migration file

  # empty notes get up-migrated to nil
  # others to a YAML serialized hash { other: old notes }
  def up
    # individually migrate notes where notes.present?
    fulls = Observation.where.not(notes: nil).where.not(notes: "")
    # set column directly to vaoid validation, time-stamping
    fulls.each { |obs| obs.update_column(:notes, to_up_notes(obs.notes)) }

    # Do the rest in a single SQL statement; drastically cuts migration time
    sql = "
      UPDATE observations
      SET notes = NULL
      WHERE notes IS null OR notes = '';
    "
    ActiveRecord::Base.connection.execute(sql)
  end

  # put non-empty notes into the "other:" field
  def to_up_notes(notes)
    notes.empty? ? nil : { other: notes }.to_yaml
  end

  # convert Observation notes from a YAML hash, except if they're nil (which
  # remain nil after down-migration, so we can leave them alone for speed)
  def down
    non_nils = Observation.where.not(notes: nil)
    non_nils.each { |obs| obs.update_column(:notes, to_down_notes(obs.notes)) }
  end

  # extract non-empty notes from the "other:" field
  def to_down_notes(notes)
    return nil if notes.nil?
    YAML.load(notes).empty? ? "" : YAML.load(notes)[:other]
  end
end
