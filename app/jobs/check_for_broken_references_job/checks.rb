# frozen_string_literal: true

# `[model, reflection_name/target_model, action]` data for
# CheckForBrokenReferencesJob. Split into its own file purely to keep the
# job class itself under Metrics/ClassLength - this module has no logic.
#
# FOLLOW-UP (not implemented here, by design - see CheckForBrokenReferencesJob
# for the alerting half of this that IS implemented): these lists are
# hand-maintained and can drift from the schema silently - an association
# gets renamed, removed, or turned polymorphic, and nothing points it out
# until someone notices data isn't getting cleaned up (or, worse, the job
# just raises). The job now alerts loudly on this (`STALE CHECK: ...` log
# lines) instead of crashing, but it doesn't self-heal the list.
#
# A future pass could derive the (model, association) pairs automatically
# via reflection introspection instead of hand-listing them:
#
#   Model.reflect_on_all_associations(:belongs_to)  # includes polymorphic
#
# ...and shrink this file down to just an override hash for the handful of
# associations whose action should NOT be the schema-derived default
# (default heuristic: `optional: true` -> :nil (or :zero for a legacy
# non-null column using 0-as-none), required -> :delete), e.g.:
#
#   ACTION_OVERRIDES = {
#     "Observation.user"       => :alert,  # never silently touch ownership
#     "Observation.name"       => :alert,
#     "Naming.user"            => :alert,
#     "CollectionNumber.user"  => :alert,
#     # ...one entry per association that's currently :alert above
#   }.freeze
#
# This only works because :alert is opt-in and rare relative to
# :delete/:nil/:zero - most associations want the mechanical default. Not
# built now because picking the right default per association (nullable
# column vs. `optional: true` vs. legacy non-null columns using 0-as-none)
# needs a careful audit of every relationship below, not something to
# invent inline while porting the script as-is.
class CheckForBrokenReferencesJob
  module Checks
    MONOMORPHIC = [
      [APIKey,                       :user,                 :delete],
      [Article,                      :rss_log,              :nil],
      [Article,                      :user,                 :zero],
      [CollectionNumber,             :user,                 :alert],
      [Comment,                      :user,                 :alert],
      [CopyrightChange,              :license,              :alert],
      [CopyrightChange,              :user,                 :alert],
      [Donation,                     :user,                 :alert],
      [ExternalLink,                 :external_site,        :alert],
      [ExternalLink,                 :user,                 :alert],
      [ExternalSite,                 :project,              :alert],
      [FieldSlip,                    :project,              :nil],
      [FieldSlip,                    :user,                 :alert],
      [GlossaryTerm,                 :rss_log,              :nil],
      [GlossaryTerm,                 :thumb_image,          :alert],
      [GlossaryTerm,                 :user,                 :alert],
      [GlossaryTermImage,            :glossary_term,        :delete],
      [GlossaryTermImage,            :image,                :delete],
      [GlossaryTerm::Version,        :glossary_term,        :delete],
      [GlossaryTerm::Version,        :user,                 :zero],
      [Herbarium,                    :location,             :alert],
      [Herbarium,                    :personal_user,        :alert],
      [HerbariumCurator,             :herbarium,            :delete],
      [HerbariumCurator,             :user,                 :delete],
      [HerbariumRecord,              :herbarium,            :alert],
      [HerbariumRecord,              :user,                 :alert],
      [Image,                        :license,              :alert],
      # [Image,                      :reviewer,             :alert],
      [Image,                        :user,                 :alert],
      [ImageVote,                    :image,                :delete],
      [ImageVote,                    :user,                 :delete],
      [Interest,                     :user,                 :delete],
      [Location,                     :description,          :nil],
      [Location,                     :rss_log,              :nil],
      [Location,                     :user,                 :zero],
      [Location::Version,            :user,                 :zero],
      [LocationDescription,          :license,              :alert],
      [LocationDescription,          :location,             :delete],
      [LocationDescription,          :project,              :nil],
      [LocationDescription,          :user,                 :zero],
      [LocationDescription::Version, :license,              :nil],
      [LocationDescription::Version, :location_description, :delete],
      [LocationDescription::Version, :user,                 :zero],
      [LocationDescriptionAdmin,     :location_description, :delete],
      [LocationDescriptionAdmin,     :user_group,           :delete],
      [LocationDescriptionAuthor,    :location_description, :delete],
      [LocationDescriptionAuthor,    :user,                 :delete],
      [LocationDescriptionEditor,    :location_description, :delete],
      [LocationDescriptionEditor,    :user,                 :delete],
      [LocationDescriptionReader,    :location_description, :delete],
      [LocationDescriptionReader,    :user_group,           :delete],
      [LocationDescriptionWriter,    :location_description, :delete],
      [LocationDescriptionWriter,    :user_group,           :delete],
      [Name,                         :correct_spelling,     :alert],
      [Name,                         :description,          :nil],
      [Name,                         :rss_log,              :nil],
      [Name,                         :synonym,              :nil],
      [Name,                         :user,                 :zero],
      [Name::Version,                :correct_spelling,     :nil],
      [Name::Version,                :name,                 :delete],
      [Name::Version,                :user,                 :zero],
      [NameDescription,              :license,              :alert],
      [NameDescription,              :name,                 :delete],
      [NameDescription,              :project,              :nil],
      [NameDescription,              :reviewer,             :alert],
      [NameDescription,              :user,                 :alert],
      [NameDescription::Version,     :license,              :nil],
      [NameDescription::Version,     :name_description,     :delete],
      [NameDescription::Version,     :user,                 :zero],
      [NameDescriptionAdmin,         :name_description,     :delete],
      [NameDescriptionAdmin,         :user_group,           :delete],
      [NameDescriptionAuthor,        :name_description,     :delete],
      [NameDescriptionAuthor,        :user,                 :delete],
      [NameDescriptionEditor,        :name_description,     :delete],
      [NameDescriptionEditor,        :user,                 :delete],
      [NameDescriptionReader,        :name_description,     :delete],
      [NameDescriptionReader,        :user_group,           :delete],
      [NameDescriptionWriter,        :name_description,     :delete],
      [NameDescriptionWriter,        :user_group,           :delete],
      [NameTracker,                  :name,                 :delete],
      [NameTracker,                  :user,                 :delete],
      [Naming,                       :name,                 :delete],
      [Naming,                       :observation,          :delete],
      [Naming,                       :user,                 :alert],
      [Observation,                  :location,             :alert],
      [Observation,                  :name,                 :alert],
      [Observation,                  :rss_log,              :nil],
      [Observation,                  :thumb_image,          :alert],
      [Observation,                  :user,                 :alert],
      [ObservationCollectionNumber,  :collection_number,    :delete],
      [ObservationCollectionNumber,  :observation,          :delete],
      [ObservationHerbariumRecord,   :herbarium_record,     :delete],
      [ObservationHerbariumRecord,   :observation,          :delete],
      [ObservationImage,             :image,                :delete],
      [ObservationImage,             :observation,          :delete],
      [ObservationView,              :observation,          :delete],
      [ObservationView,              :user,                 :delete],
      [Occurrence,                   :field_slip,           :nil],
      [Occurrence,                   :primary_observation,  :delete],
      [Project,                      :admin_group,          :alert],
      [Project,                      :image,                :alert],
      [Project,                      :location,             :alert],
      [Project,                      :rss_log,              :nil],
      [Project,                      :user,                 :alert],
      [Project,                      :user_group,           :alert],
      [ProjectImage,                 :image,                :delete],
      [ProjectImage,                 :project,              :delete],
      [ProjectMember,                :project,              :delete],
      [ProjectMember,                :user,                 :delete],
      [ProjectObservation,           :observation,          :delete],
      [ProjectObservation,           :project,              :delete],
      [ProjectSpeciesList,           :project,              :delete],
      [ProjectSpeciesList,           :species_list,         :delete],
      [Publication,                  :user,                 :alert],
      [RssLog,                       :article,              :delete],
      [RssLog,                       :glossary_term,        :delete],
      [RssLog,                       :location,             :delete],
      [RssLog,                       :name,                 :delete],
      [RssLog,                       :observation,          :delete],
      [RssLog,                       :project,              :delete],
      [RssLog,                       :species_list,         :delete],
      [Sequence,                     :observation,          :alert],
      [Sequence,                     :user,                 :alert],
      [SpeciesList,                  :location,             :nil],
      [SpeciesList,                  :rss_log,              :nil],
      [SpeciesList,                  :user,                 :alert],
      [SpeciesListObservation,       :observation,          :delete],
      [SpeciesListObservation,       :species_list,         :delete],
      [TranslationString,            :language,             :alert],
      [TranslationString,            :user,                 :zero],
      [TranslationString::Version,   :translation_string,   :delete],
      [TranslationString::Version,   :user,                 :zero],
      [User,                         :image,                :nil],
      [User,                         :license,              :alert],
      [User,                         :location,             :nil],
      [UserGroupUser,                :user,                 :delete],
      [UserGroupUser,                :user_group,           :delete],
      [VisualGroup,                  :visual_model,         :alert],
      [VisualGroupImage,             :image,                :delete],
      [VisualGroupImage,             :visual_group,         :delete],
      [Vote,                         :naming,               :delete],
      [Vote,                         :observation,          :delete],
      [Vote,                         :user,                 :delete]
    ].freeze

    POLYMORPHIC = [
      [Comment,         Name],
      [Comment,         Observation],
      [Comment,         Project],
      [Comment,         Location],
      [Comment,         LocationDescription],
      [Comment,         NameDescription],
      [Comment,         SpeciesList],
      [CopyrightChange, Image],
      [ExternalLink,    Observation],
      [Interest,        Observation],
      [Interest,        Name],
      [Interest,        Location],
      [Interest,        Project],
      [Interest,        SpeciesList],
      [Interest,        NameTracker]
    ].freeze
  end
end
