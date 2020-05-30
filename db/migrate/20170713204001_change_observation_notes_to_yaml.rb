class ChangeObservationNotesToYaml < ActiveRecord::Migration[4.2]
  # ***** THIS MIGRATION MUST BE RUN WITH Observation::serialize :notes ********

  # migrate notes to a YAML serialized hash, any notes converted to the
  # value of the serialized "Other:" key
  # If notes nil or not present, then convert them to a serialized empty hash
  #  notes: "abc" => notes: { Other: "abc" }
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
  # the serialized "Other:" key
  # If there's no such key, revert to empty string
  #  notes: { color: "red", Other: "abc" } => "abc"
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
  # putting non-empty notes into the "Other:" field
  def to_up_notes(raw_notes)
    raw_notes.present? ? { Other: raw_notes } : {}
  end

  # Return desired reverted notes
  # Extract the "Other:" field; otherwise return a blank string
  def to_down_notes(notes)
    # notes.is_a?(Hash) ? (notes)[:Other] : ""
    notes.empty? ? "" : (notes)[:Other]
  end
end
