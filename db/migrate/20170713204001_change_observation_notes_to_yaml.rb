class ChangeObservationNotesToYaml < ActiveRecord::Migration
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
