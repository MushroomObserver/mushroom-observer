require "test_helper"

# TODO - delete this test file after production db is migrated and
# and we are totally ok with it

# test the up and down migration statements for observation.notes format
class NotesMigrateCommandTest < UnitTestCase
  # temporary test of commands to up-migrate notes format to YAML
  # and down-migrate back to original
  def test_up_and_down
    # Modify some random fixtures' notes to pre-migration form
    observations   = []
    original_notes = []

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

    # Adolf's formatting, carriage return, newline
    observations   << observations(:other_user_owns_naming_obs)
    original_notes << %Q{Original Herbarium Label: _Annulohypoxylon multiforme_ (Fr.) Y.M. Ju, J.D. Rogers & H.M. Hsieh\r\nSyn.: _Hypoxylon multiforme_ (Fr.) Fr.\r\nHerbarium Specimen: UBC F26015}

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

    # Prove that unserialized notes are up-migrated correctly
    observations.each_index do |i|
      up_notes = observations[i].reload.notes
      if original_notes[i].nil? || original_notes[i] == ""
        assert_equal(
          {}, up_notes,
          "Obs #{observations[i].id} up notes should be empty hash"
          )
      else
        assert_equal(
          original_notes[i], up_notes[:other],
          "Obs #{observations[i].id} notes not upmigrated correctly"
        )
      end
      # and timestamps are untouched
      assert_equal(original_updated[i], observations[i].updated_at)
    end


    ############################################################################
    #
    # Prove that down method works
    #
    ############################################################################

    # It should restore everything except those which were originally nil
    # because both "" and nil were up-migrated to {}.
    # So after migration there's no way to differentiate them and
    # both are reverted to empty string.
    down

    observations.each_index do |i|
      obs = observations[i]
      raw_down_notes = read_notes_without_serializing(obs)
      if original_notes[i].nil? || original_notes[i].empty?
        assert_equal("", raw_down_notes)
      else
        assert_equal(original_notes[i], raw_down_notes)
      end
    end
  end

  # Read notes, skipping serialization, callbacks, validation
  def read_notes_without_serializing(obs)
    Observation.connection.exec_query("
      SELECT notes FROM observations WHERE id = #{obs.id}
    ").rows.first.first
  end

  ##########################################################################
  # remainder of this file is what gets moved to the migration file


  # ***** THIS MIGRATION MUST BE RUN WITH Observation::serialize :notes ********

  # migrate notes to a YAML serialized hash, any notes converted to the
  # value of the serialized "other:" key
  # If notes nil or not present, then convert them to a serialized empty hash
  #  notes: "abc" => notes: { other: "abc" }
  #  notes: ""    => notes: { }
  #  notes: nil   => notes: { }
  def up
    individually_migrate_nonempty_nonnull_notes
    batch_migrate_empty_and_null_notes
  end

  def individually_migrate_nonempty_nonnull_notes
    neither_empty_nor_null.each do |id, raw_notes|
      # write them with serializing, but without callbacks or validations
      Observation.find(id).update_column(:notes, to_up_notes(raw_notes))
    end
  end

  # returns array of hashes of ids, notes
  #  [ { id: 1st id, notes: notes }, { id: 2nd id, notes: notes } ...]
  # find_by_sql does not work;
  # it tries to deserialize the unmigrated notes (and throws an error)
  def neither_empty_nor_null
    Observation.connection.exec_query("
      SELECT id, notes FROM observations
      WHERE notes != #{Observation.connection.quote("")}
      AND notes IS NOT NULL
    ").rows
  end

  def batch_migrate_empty_and_null_notes
    Observation.connection.execute("
      UPDATE observations
      SET notes = #{Observation.connection.quote({}.to_yaml)}
      WHERE notes = #{Observation.connection.quote("")}
      OR notes IS NULL
    ")
  end

  # Revert Observation notes from YAML serialized notes, extracting the value of
  # the serialized "other:" key
  # If there's no such key, revert to empty string
  #  notes: { color: "red", other: "abc" } => "abc"
  #  notes: { color: "red" }               => ""
  #  notes: { }                            => ""
  def down
    individually_revert_nonempty_notes
    batch_revert_empty_notes
  end

  def individually_revert_nonempty_notes
    Observation.where.not(notes: "").each do |obs|
      write_notes_without_serializing(
        obs: obs, notes: to_down_notes(obs.notes)
      )
    end
  end

  # Write notes, skipping serialization, callbacks, validation
  def write_notes_without_serializing(obs:, notes:)
    Observation.connection.execute("
      UPDATE observations
      SET notes = #{Observation.connection.quote(notes)}
      WHERE id = #{obs.id}
    ")
  end

  def batch_revert_empty_notes
    Observation.connection.execute("
      UPDATE observations
      SET notes = #{Observation.connection.quote("")}
      WHERE notes = #{Observation.connection.quote({}.to_yaml)}
    ")
  end

  # Return desired up-migrated, serialized notes
  # putting non-empty notes into the "other:" field
  def to_up_notes(raw_notes)
    raw_notes.present? ? { other: raw_notes } : {}
  end

  # Return desired reverted notes
  # Extract the "other:" field; otherwise return a blank string
  def to_down_notes(notes)
    # notes.is_a?(Hash) ? (notes)[:other] : ""
    notes.empty? ? "" : (notes)[:other]
  end
end
