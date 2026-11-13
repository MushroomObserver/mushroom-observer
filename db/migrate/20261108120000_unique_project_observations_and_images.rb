# frozen_string_literal: true

# One row per (project, observation) and per (project, image) (#4181).
# Two writers adding the same observation at once -- the observation
# form and DetectFieldSlipQRJob, both filing a slip's observation into
# its project -- each found no row and each inserted one. With these
# indexes, `insert_all` skips the row the other writer got in first.
#
# The repair, script/dedupe_project_links.rb, removes the existing
# duplicates. Both tables are small; the indexes build online.
class UniqueProjectObservationsAndImages < ActiveRecord::Migration[7.2]
  REPAIR = "bin/rails runner script/dedupe_project_links.rb --apply"

  # Copies of the tables as this migration needs them, rather than the
  # application's models -- those go on changing after this migration
  # is written.
  class MigrationProjectObservation < ActiveRecord::Base
    self.table_name = "project_observations"
  end

  class MigrationProjectImage < ActiveRecord::Base
    self.table_name = "project_images"
  end

  def up
    refuse_until_repaired
    add_index(:project_observations, [:project_id, :observation_id],
              unique: true, name: "index_project_observations_unique")
    add_index(:project_images, [:project_id, :image_id],
              unique: true, name: "index_project_images_unique")
  end

  def down
    remove_index(:project_observations,
                 name: "index_project_observations_unique")
    remove_index(:project_images, name: "index_project_images_unique")
  end

  private

  def refuse_until_repaired
    observations = duplicate_count(MigrationProjectObservation,
                                   :observation_id)
    images = duplicate_count(MigrationProjectImage, :image_id)
    return if (observations + images).zero?

    raise(<<~MESSAGE)
      #{observations} project/observation pairs and #{images}
      project/image pairs have more than one row, so the unique indexes
      cannot be added yet.

      Run the repair first, reading its dry run before applying it:
        #{REPAIR.sub(" --apply", "")}
        #{REPAIR}
    MESSAGE
  end

  def duplicate_count(model, column)
    model.group(:project_id, column).
      having(Arel.star.count.gt(1)).count.size
  end
end
