# frozen_string_literal: true

class AddImageOptOuts < ActiveRecord::Migration[7.2]
  def change
    add_column(:users, :inat_import_opt_out, :boolean,
               default: false, null: false)
    create_excluded_inat_users
    create_image_purges
  end

  private

  def create_excluded_inat_users
    create_table(:excluded_inat_users) do |t|
      t.string(:inat_login, limit: 40, null: false)
      t.bigint(:inat_user_id)
      t.integer(:user_id)
      t.text(:reason)
      t.timestamps
      t.index(:inat_login, unique: true)
      t.index(:inat_user_id)
    end
  end

  def create_image_purges
    create_table(:image_purges) do |t|
      t.integer(:user_id)
      t.integer(:target_user_id)
      t.string(:inat_login, limit: 40)
      t.integer(:state, default: 0, null: false)
      purge_counts(t)
      t.text(:error)
      t.datetime(:notified_at)
      t.datetime(:ended_at)
      t.timestamps
      t.index(:target_user_id)
      t.index(:inat_login)
    end
  end

  def purge_counts(table)
    [:image_count, :deleted_image_count, :cleared_notes_count,
     :placeholder_count].each do |column|
      table.integer(column, default: 0, null: false)
    end
  end
end
