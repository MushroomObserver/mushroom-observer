# frozen_string_literal: true

class AddBatchesToSolidQueue < ActiveRecord::Migration[7.2]
  def change
    # Fresh installs create all of this with the base schema, so skip
    # anything that already exists
    add_column(:solid_queue_jobs, :batch_id, :bigint, if_not_exists: true)
    add_index(:solid_queue_jobs, :batch_id, if_not_exists: true)
    create_batches
    create_batch_executions
  end

  private

  def create_batches
    create_table(:solid_queue_batches, if_not_exists: true) do |t|
      t.string(:active_job_batch_id)
      t.string(:description)
      t.text(:on_finish)
      t.text(:on_success)
      t.text(:on_failure)
      t.text(:metadata)
      batch_counters(t)
      batch_timestamps(t)
      t.datetime(:created_at, null: false)
      t.datetime(:updated_at, null: false)

      t.index(:active_job_batch_id, unique: true)
      t.index(:finished_at)
    end
  end

  def batch_counters(table)
    table.integer(:total_jobs, default: 0, null: false)
    table.integer(:completed_jobs, default: 0, null: false)
    table.integer(:failed_jobs, default: 0, null: false)
  end

  def batch_timestamps(table)
    table.datetime(:enqueued_at)
    table.datetime(:finished_at)
    table.datetime(:failed_at)
  end

  def create_batch_executions
    create_table(:solid_queue_batch_executions, if_not_exists: true) do |t|
      t.bigint(:job_id, null: false)
      t.bigint(:batch_id, null: false)
      t.datetime(:created_at, null: false)

      t.index(:job_id, unique: true)
      t.index(:batch_id)
      t.foreign_key(:solid_queue_batches, column: :batch_id,
                                          on_delete: :cascade)
      t.foreign_key(:solid_queue_jobs, column: :job_id, on_delete: :cascade)
    end
  end
end
