# TODO - delete this file after production db is migrated and
# and we are totally ok with it
require "test_helper"

# test the up and down migration statements for observation.notes format
class NotesMigrateCommandTest < UnitTestCase
  # temporary test of commands to up-migrate notes format to YAML
  # and down-migrate back to original
  def test_up_and_down
    # Modify some random fixtures' notes to pre-migration form
    observations   = []
    original_notes = []

    # duplicates a later one as observations.first
    observations   << observations(:agaricus_campestras_obs)
    original_notes << %Q{\\}

    # nil
    nil_notes_obs   = observations(:sortable_obs_users_second_obs)
    observations   << nil_notes_obs
    original_notes << nil

    # blank
    blank_notes_obs = observations(:sortable_obs_users_first_obs)
    observations   << blank_notes_obs
    original_notes << ""

    # single quote
    observations   << observations(:unlisted_rolf_obs)
    original_notes << %Q{with 'french' fries}

    # double quote
    observations   << observations(:unequal_positive_namings_obs)
    original_notes <<  %Q{with "french" fries}

    # newline
    observations   << observations(:imged_unvouchered_obs)
    original_notes << %Q{a\nb}

    # carriage return
    observations   << observations(:all_namings_deprecated_obs)
    original_notes << %Q{a\rb}

    # backslash
    observations   << observations(:authored_with_naming_obs)
    original_notes << %Q{\\}

    # simple notes
    observations   << observations(:imageless_unvouchered_obs)
    original_notes << "simple notes"

   # linefeeds, textile markup, single quote
    observations   << observations(:vouchered_obs)
    original_notes << %Q{_Agaricus_ but what species?  I was going to guess _A. subrutilescens_, but then noticed that cap flesh stains yellow near cuticle when cut.  Both Arora and Trudell & Ammirati say that _A. subrutilescens_,is non-staining.\nIn duff (and possibly bark dust).  Nearest tree was a spruce.\nI do not have a mature specimen, so cannot tell real maximum sizes and other characters.\nCap\n* appears brown from a distance, but actually white, with abundant brown fibrils\n* max diameter 6.5 cm\n* mild almond odor and taste\n* flesh white, 1 cm thick\n* cap flesh stains yellow near cuticle when cut.  See 3rd photo.\nGills\n* free\n* close\n* young gills off-white\n* 6mm\nStipe\n* shaggy white starting at partial veil downward for about 1/2 length of stipe, then brown fibrils\n* almost all the stipe was below the duff; only the cap was showing.  See 2nd photo\n* 17.5 cm long\n* 2.5 cm thick\n* slightly bulbous base\n* almond taste\n* hollow\n* membranous partial veil still present in all specimens, so I cannot be certain what annulus will look like.  But by how it's attached to the stipe, I'm guessing it will be skirt-like\n* stipe does not stain on cutting or bruising\n    }

    # linefeeds, textile markup, double quotes
    observations   << observations(:vouchered_imged_obs)
    original_notes << %Q{\n+Collectors+: Sally Visher, Joseph D. Cohen\n+Substrate+: Soil\n+Habitat+:  below undergrowth in relatively open area in coastal "??Picea sitchensis??":http://eol.org/pages/1033696 (Sitka Spruce) forest.\n+Nearest large tree+:  "??Picea sitchensis??":http://eol.org/pages/1033696 (Sitka Spruce).  (No other conifer species anywhere near collection.)\n+Chemical+: Cap cuticle may stain dark red in KOH; it's hard to tell because of the age and water-logged state of this mushroom. Cap flesh negative in KOH.\n+Spores+: Brown\nbq. +Measurements+:\nPiximètre 5.9 R 1530 : le 20/06/2017 à 16:55:06.1172147\n(12.4) 12.5 - 14.5 (15.8) × (4.9) 5.8 - 6.7 (6.8) µm\nQ = 2 - 2.3 (2.7) ; N = 10\n**Me = 13.6 × 6.2 µm ; Qe = 2.2**\n+Other+:  The blue staining seen in some photos appears to originate in the cap flesh around its edges.  The final 3 macro photos (with white background) were taken ~2.5 hours after collecting this mushroom.}

    # something which looks like a symbol mid-line
    observations   << observations(:updated_2013_obs)
    original_notes << %Q{ Used “North American Boletes” by Bessette and Roody for ID.\n[admin – Sat Aug 14 02:00:21 +0000 2010]: Changed location name from ‘Fairfield, Ct.’ to ‘Fairfield, Connecticut, USA’}

    observations.each_index do |i|
      if original_notes[i].nil?
        write_notes_without_serializing(
          obs: observations[i], notes: ""
        )
      else
        write_notes_without_serializing(
          obs: observations[i], notes: original_notes[i]
        )
      end
    end

    original_updated = observations.map(&:updated_at)

    ############################################################################
    #
    # Prove that up method works
    #
    ############################################################################

    up

    # Prove that unserialized notes are up-migrated to
    # serialized { other: original_notes },
    # Except nil notes are up-migrated to serialized empty string
    observations.size.times do |i|
      up_notes = observations[i].reload.notes
      if original_notes[i].nil? || original_notes[i] == ""
        assert_equal(
          "", up_notes,
          "Obs #{observations[i].id} up notes should be empty string"
          )
      else
        assert_equal(
          original_notes[i], up_notes[:other],
          "Obs #{observations[i].id} notes not upmigrated correctly"
        )
      end
      assert_equal(original_updated[i], observations[i].updated_at)
    end

    ############################################################################
    #
    # Prove that down method works
    #
    ############################################################################

    # It should restore everything except those which were originally ""
    # because both "" and nil were up-migrated to nil.
    # So after up-mgration there's no way to differentiate them.
    # Both will be down-migrated to empty string.
    down

    observations.size.times do |i|
      obs = observations[i]
      raw_down_notes = read_notes_without_serializing(obs)
      if original_notes[i].nil? || original_notes[i].empty?
        assert_equal("", raw_down_notes)
      else
        assert_equal(original_notes[i], raw_down_notes)
      end
    end
  end

  ##########################################################################
  # remainder of this file is what gets moved to the migration file


  # ***** THIS MIGRATION MUST BE RUN WITH Observation::serialize :notes ********
  #
  # nil notes get up-migrated to YAML serialized empty string
  # others to a YAML serialized hash { other: old notes }
  def up
    Observation.all.each do |obs|
      raw_notes = read_notes_without_serializing(obs)
      # write them with serializing
      obs.update_column(:notes, to_up_notes(raw_notes))
    end
  end

  # convert Observation notes from a YAML hash
  def down
    Observation.all.each do |obs|
      serialized_notes = obs.reload.notes
      down_notes = to_down_notes(serialized_notes)
      write_notes_without_serializing(obs: obs, notes: down_notes)
    end
  end

  # Read notes, skipping serialization, callbacks, validation
  def read_notes_without_serializing(obs)
    ActiveRecord::Base.connection.exec_query("
      SELECT notes FROM observations WHERE id = #{obs.id}
    ").rows.first.first
  end

  # Write notes, skipping serialization, callbacks, validation
  def write_notes_without_serializing(obs:, notes:)
    ActiveRecord::Base.connection.execute("
      UPDATE observations
      SET notes = \"#{escape_for_sql(notes)}\"
      WHERE id = #{obs.id}
    ")
  end

  # Return desired up-migrated notes post-serialization
  # put non-empty notes into the "other:" field
  def to_up_notes(raw_notes)
    if raw_notes.present?
      { other: raw_notes }
    elsif raw_notes.nil?
      ""
    else
      raw_notes
    end
  end

  # Return desired reverted notes
  # Extract the "other:" field; otherwise return a blank string
  def to_down_notes(notes)
    notes.is_a?(Hash) ? (notes)[:other] : ""
  end

  # returns a string suitable for inclusion in a SQL statement,
  # escaping the characters for which MySQL requires escaping
  # input is a double-quoted string
  # The 2nd gsub is needed because I can't figure out how to get
  # a double quote to behave properly inside character class
  # inside the capture group
  def escape_for_sql(str)
    str.gsub(/([\0\b\n\r\t\\])/, '\\\\\1').gsub(%q{"}, %q{\\\\"})
  end
end
