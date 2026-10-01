# frozen_string_literal: true

class AddSkeletonOmissionsToObservations < ActiveRecord::Migration[7.2]
  def change
    add_column(:observations, :skeleton_omissions, :text)
  end
end
