# frozen_string_literal: true

#
#  = Source Model
#
#  External data source from which observations are imported (iNat,
#  MyCoPortal, etc.). Observations link to a Source via
#  `Observation#source_id`, with `Observation#external_id` holding
#  the source-system's stable identifier for that observation.
#
#  This is the "external data source" axis of the two-axis model in
#  #4208 — distinct from the `Observation#source` enum, which records
#  the *entry agent* (mo_website, mo_android_app, etc.). A row can
#  have both: e.g. an observation entered via mo_website and later
#  linked to its iNat counterpart will carry both `source = mo_website`
#  and `source_id = <iNaturalist>`.
#
#  == Attributes
#
#  id::                       Locally unique numerical id.
#  name::                     Display name, unique. e.g. "iNaturalist".
#  url::                      Public URL of the source.
#  description::              Free-form description.
#  last_successful_sync_at::  Timestamp of the most recent successful
#                             sync run; read by the sync job (#4215).
#
#  == Instance methods
#
#  observations::  Observations imported from this source.
#
class Source < AbstractModel
  INATURALIST_NAME = "iNaturalist"

  has_many :observations, dependent: :restrict_with_exception,
                          inverse_of: :external_source

  validates :name, presence: true, length: { maximum: 100 },
                   uniqueness: { case_sensitive: false }
  validates :url, length: { maximum: 1024 }, allow_blank: true

  # Lookup for the iNaturalist row, seeded by the CreateSources
  # migration. Cheap (one row by indexed unique name); avoids
  # caching to keep test fixture reloads safe.
  def self.inaturalist
    find_by!(name: INATURALIST_NAME)
  end
end
