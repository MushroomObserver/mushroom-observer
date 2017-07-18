class ChangeObservationNotesToYaml < ActiveRecord::Migration
  # ***** THIS MIGRATION MUST BE RUN WITH Observation::serialize :notes ********

  # migrate notes to a YAML serialized hash, any notes converted to the
  # value of the serialized "other:" key
  #   notes: "abc" => notes: { other: "abc" }
  # If notes nil or not present, then convert them to a serialized empty string
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
      WHERE notes != \"\" AND notes IS NOT NULL ;
    ").rows
  end

  def batch_migrate_empty_and_null_notes
    Observation.connection.execute("
      UPDATE observations
      SET notes = \"--- ''\n\"
      WHERE notes = \"\" OR notes IS NULL
    ")
  end

  # revert Observation notes from YAML serialized notes, extracting the value of
  # the serialized "other:" key
  #   notes: { color: "red", other: "abc" } => "abc"
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
      SET notes = \"#{escape_for_sql(notes)}\"
      WHERE id = #{obs.id}
    ")
  end

  def batch_revert_empty_notes
    Observation.connection.execute("
      UPDATE observations
      SET notes = \"\"
      WHERE notes = \"--- ''\n\"
    ")
  end

  # Return desired up-migrated, serialized notes
  # putting non-empty notes into the "other:" field
  def to_up_notes(raw_notes)
    raw_notes.present? ? { other: raw_notes } : ""
  end

  # Return desired reverted notes
  # Extract the "other:" field; otherwise return a blank string
  def to_down_notes(notes)
    notes.is_a?(Hash) ? (notes)[:other] : ""
  end

  # Return a string suitable for inclusion in a SQL statement,
  # escaping the characters for which MySQL requires escaping
  # Input is a double-quoted string.
  # The 2nd gsub is needed because I can't figure out how to get
  # a double quote to behave properly inside character class
  # inside the capture group
  def escape_for_sql(str)
    str.gsub(/([\0\b\n\r\t\\])/, '\\\\\1').gsub(%q{"}, %q{\\\\"})
  end
end
