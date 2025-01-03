class UpdateEnumColumnValues < ActiveRecord::Migration[7.1]
  # Default Rails enum values must start at zero.
  # This migration gets the following columns on a zero basis.
  # Name.rank and Observation.source get a new "unused" zero value.
  def up
    User.where.not(thumbnail_size: nil).
      update_all(thumbnail_size: User[:thumbnail_size] - 1)
    User.where.not(image_size: nil).
      update_all(image_size: User[:image_size] - 1)
    User.where.not(votes_anonymous: nil).
      update_all(votes_anonymous: User[:votes_anonymous] - 1)
    User.where.not(location_format: nil).
      update_all(location_format: User[:location_format] - 1)
    User.where.not(hide_authors: nil).
      update_all(hide_authors: User[:hide_authors] - 1)
    User.where.not(keep_filenames: nil).
      update_all(keep_filenames: User[:keep_filenames] - 1)
    LocationDescription.where.not(source_type: nil).
      update_all(source_type: LocationDescription[:source_type] - 1)
    NameDescription.where.not(review_status: nil).
      update_all(review_status: NameDescription[:review_status] - 1)
    NameDescription.where.not(review_status: nil).
      update_all(source_type: NameDescription[:source_type] - 1)
    ProjectMember.where.not(trust_level: nil).
      update_all(trust_level: ProjectMember[:trust_level] - 1)
  end

  def down
    User.where.not(thumbnail_size: nil).
      update_all(thumbnail_size: User[:thumbnail_size] + 1)
    User.where.not(image_size: nil).
      update_all(image_size: User[:image_size] + 1)
    User.where.not(votes_anonymous: nil).
      update_all(votes_anonymous: User[:votes_anonymous] + 1)
    User.where.not(location_format: nil).
      update_all(location_format: User[:location_format] + 1)
    User.where.not(hide_authors: nil).
      update_all(hide_authors: User[:hide_authors] + 1)
    User.where.not(keep_filenames: nil).
      update_all(keep_filenames: User[:keep_filenames] + 1)
    LocationDescription.where.not(source_type: nil).
      update_all(source_type: LocationDescription[:source_type] + 1)
    NameDescription.where.not(review_status: nil).
      update_all(review_status: NameDescription[:review_status] + 1)
    NameDescription.where.not(review_status: nil).
      update_all(source_type: NameDescription[:source_type] + 1)
    ProjectMember.where.not(trust_level: nil).
      update_all(trust_level: ProjectMember[:trust_level] + 1)
  end
end
