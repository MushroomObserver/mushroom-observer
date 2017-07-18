class ChangeObservationNotesToYaml < ActiveRecord::Migration
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
