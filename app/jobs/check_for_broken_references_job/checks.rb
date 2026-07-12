# frozen_string_literal: true

# Derives the (model, association) pairs CheckForBrokenReferencesJob checks
# from live `belongs_to`/`has_many`/`has_one` reflections, instead of a
# hand-maintained list - so a renamed, removed, or newly-polymorphic
# association can't silently drift out of sync with what's actually checked.
#
# What's derived automatically (no maintenance needed):
#   - which monomorphic `belongs_to` associations exist, including the
#     handful that only live on a `::Version` sibling table (e.g.
#     `Name::Version.correct_spelling`, borrowed from `Name`'s own
#     reflection because `name_versions.correct_spelling_id` exists);
#   - which polymorphic `belongs_to` associations exist (`Comment#target`,
#     `Interest#target`, etc.) and every model that's a valid target for
#     each - found via the inverse `has_many/has_one ..., as: :target`
#     declaration, not a hand-listed pairing.
#
# What's still a human judgment call, and lives in ACTIONS below: which
# action (:alert/:delete/:nil/:zero) is correct for a given monomorphic
# association. This was audited against schema nullability directly (see
# PR description) - nullability alone predicts the right action for barely
# 40% of associations, so there's no shrinking this to a "default + small
# override" table. Anything not listed in ACTIONS falls back to the safe
# DEFAULT_ACTION (:alert - report, never guess destructively) rather than
# going unchecked, and CheckForBrokenReferencesJob logs a one-time nudge
# ("NEEDS ACTION ENTRY") so a human can categorize it properly. Polymorphic
# checks have no action table at all - a dangling polymorphic target always
# means the referencing row is deleted, so there's nothing to look up.
class CheckForBrokenReferencesJob
  module Checks
    DEFAULT_ACTION = :alert

    ACTIONS = {
      "APIKey.user" => :delete,
      "Article.rss_log" => :nil,
      "Article.user" => :zero,
      "CollectionNumber.user" => :alert,
      "Comment.user" => :alert,
      "CopyrightChange.license" => :alert,
      "CopyrightChange.user" => :alert,
      "Donation.user" => :alert,
      "ExternalLink.external_site" => :alert,
      "ExternalLink.user" => :alert,
      "ExternalSite.project" => :alert,
      "FieldSlip.project" => :nil,
      "FieldSlip.user" => :alert,
      "FieldSlipJobTracker.user" => :alert,
      "GlossaryTerm.rss_log" => :nil,
      "GlossaryTerm.thumb_image" => :alert,
      "GlossaryTerm.user" => :alert,
      "GlossaryTerm::Version.glossary_term" => :delete,
      "GlossaryTerm::Version.user" => :zero,
      "GlossaryTermImage.glossary_term" => :delete,
      "GlossaryTermImage.image" => :delete,
      "Herbarium.location" => :alert,
      "Herbarium.personal_user" => :alert,
      "HerbariumCurator.herbarium" => :delete,
      "HerbariumCurator.user" => :delete,
      "HerbariumRecord.herbarium" => :alert,
      "HerbariumRecord.user" => :alert,
      "Image.license" => :alert,
      "Image.user" => :alert,
      "ImageVote.image" => :delete,
      "ImageVote.user" => :delete,
      "InatImport.user" => :alert,
      "Interest.user" => :delete,
      "Location.description" => :nil,
      "Location.rss_log" => :nil,
      "Location.user" => :zero,
      "Location::Version.location" => :delete,
      "Location::Version.user" => :zero,
      "LocationDescription.license" => :alert,
      "LocationDescription.location" => :delete,
      "LocationDescription.project" => :nil,
      "LocationDescription.user" => :zero,
      "LocationDescription::Version.license" => :nil,
      "LocationDescription::Version.location_description" => :delete,
      "LocationDescription::Version.user" => :zero,
      "LocationDescriptionAdmin.location_description" => :delete,
      "LocationDescriptionAdmin.user_group" => :delete,
      "LocationDescriptionAuthor.location_description" => :delete,
      "LocationDescriptionAuthor.user" => :delete,
      "LocationDescriptionEditor.location_description" => :delete,
      "LocationDescriptionEditor.user" => :delete,
      "LocationDescriptionReader.location_description" => :delete,
      "LocationDescriptionReader.user_group" => :delete,
      "LocationDescriptionWriter.location_description" => :delete,
      "LocationDescriptionWriter.user_group" => :delete,
      "Name.correct_spelling" => :alert,
      "Name.description" => :nil,
      "Name.rss_log" => :nil,
      "Name.synonym" => :nil,
      "Name.user" => :zero,
      "Name::Version.correct_spelling" => :nil,
      "Name::Version.name" => :delete,
      "Name::Version.user" => :zero,
      "NameDescription.license" => :alert,
      "NameDescription.name" => :delete,
      "NameDescription.project" => :nil,
      "NameDescription.reviewer" => :alert,
      "NameDescription.user" => :alert,
      "NameDescription::Version.license" => :nil,
      "NameDescription::Version.name_description" => :delete,
      "NameDescription::Version.user" => :zero,
      "NameDescriptionAdmin.name_description" => :delete,
      "NameDescriptionAdmin.user_group" => :delete,
      "NameDescriptionAuthor.name_description" => :delete,
      "NameDescriptionAuthor.user" => :delete,
      "NameDescriptionEditor.name_description" => :delete,
      "NameDescriptionEditor.user" => :delete,
      "NameDescriptionReader.name_description" => :delete,
      "NameDescriptionReader.user_group" => :delete,
      "NameDescriptionWriter.name_description" => :delete,
      "NameDescriptionWriter.user_group" => :delete,
      "NameTracker.name" => :delete,
      "NameTracker.user" => :delete,
      "Naming.name" => :delete,
      "Naming.observation" => :delete,
      "Naming.user" => :alert,
      "Observation.collector_user" => :alert,
      "Observation.inat_import" => :nil,
      "Observation.location" => :alert,
      "Observation.name" => :alert,
      "Observation.occurrence" => :nil,
      "Observation.rss_log" => :nil,
      "Observation.thumb_image" => :alert,
      "Observation.user" => :alert,
      "ObservationCollectionNumber.collection_number" => :delete,
      "ObservationCollectionNumber.observation" => :delete,
      "ObservationHerbariumRecord.herbarium_record" => :delete,
      "ObservationHerbariumRecord.observation" => :delete,
      "ObservationImage.image" => :delete,
      "ObservationImage.observation" => :delete,
      "ObservationView.observation" => :delete,
      "ObservationView.user" => :delete,
      "Occurrence.field_slip" => :nil,
      "Occurrence.primary_observation" => :delete,
      "Occurrence.user" => :alert,
      "Project.admin_group" => :alert,
      "Project.image" => :alert,
      "Project.location" => :alert,
      "Project.rss_log" => :nil,
      "Project.user" => :alert,
      "Project.user_group" => :alert,
      "ProjectAlias.project" => :alert,
      "ProjectExcludedObservation.observation" => :delete,
      "ProjectExcludedObservation.project" => :delete,
      "ProjectImage.image" => :delete,
      "ProjectImage.project" => :delete,
      "ProjectMember.project" => :delete,
      "ProjectMember.user" => :delete,
      "ProjectObservation.observation" => :delete,
      "ProjectObservation.project" => :delete,
      "ProjectSpeciesList.project" => :delete,
      "ProjectSpeciesList.species_list" => :delete,
      "ProjectTargetLocation.location" => :delete,
      "ProjectTargetLocation.project" => :delete,
      "ProjectTargetName.name" => :delete,
      "ProjectTargetName.project" => :delete,
      "Publication.user" => :alert,
      "RssLog.article" => :delete,
      "RssLog.glossary_term" => :delete,
      "RssLog.location" => :delete,
      "RssLog.name" => :delete,
      "RssLog.observation" => :delete,
      "RssLog.project" => :delete,
      "RssLog.species_list" => :delete,
      "Sequence.observation" => :alert,
      "Sequence.user" => :alert,
      "SpeciesList.location" => :nil,
      "SpeciesList.rss_log" => :nil,
      "SpeciesList.user" => :alert,
      "SpeciesListObservation.observation" => :delete,
      "SpeciesListObservation.species_list" => :delete,
      "TranslationString.language" => :alert,
      "TranslationString.user" => :zero,
      "TranslationString::Version.language" => :nil,
      "TranslationString::Version.translation_string" => :delete,
      "TranslationString::Version.user" => :zero,
      "User.image" => :nil,
      "User.license" => :alert,
      "User.location" => :nil,
      "UserGroupUser.user" => :delete,
      "UserGroupUser.user_group" => :delete,
      "UserStats.user" => :alert,
      "VisualGroup.visual_model" => :alert,
      "VisualGroupImage.image" => :delete,
      "VisualGroupImage.visual_group" => :delete,
      "Vote.naming" => :delete,
      "Vote.observation" => :delete,
      "Vote.user" => :delete
    }.freeze

    def self.action_for(model, reflection_name)
      ACTIONS.fetch("#{model.name}.#{reflection_name}", DEFAULT_ACTION)
    end

    def self.action_defined?(model, reflection_name)
      ACTIONS.key?("#{model.name}.#{reflection_name}")
    end

    # ACTIONS entries naming an association that no longer exists (renamed,
    # removed, or turned polymorphic) - the ACTIONS-table equivalent of the
    # job's "STALE CHECK" log line, since the association LIST itself can
    # no longer drift (it's derived live every run).
    def self.stale_action_entries
      live_keys = monomorphic_associations.map { |m, a| "#{m.name}.#{a}" }
      ACTIONS.keys - live_keys
    end

    # [model, reflection_name] for every real, checkable monomorphic
    # `belongs_to` - excludes polymorphic associations (handled separately
    # below) and typed-polymorphic "views" that just reuse a polymorphic
    # foreign key for a scoped, typed join (e.g. a hypothetical
    # `Comment#location` scoped on `target_id`) - those are already
    # covered by the polymorphic check on the shared column.
    def self.monomorphic_associations
      all_models.flat_map { |model| monomorphic_associations_for(model) }
    end

    # [model, reflection_name] for every polymorphic `belongs_to` in the app
    # (currently always named `:target`, but this doesn't assume that).
    def self.polymorphic_associations
      all_models.flat_map do |model|
        model.reflect_on_all_associations(:belongs_to).
          select(&:polymorphic?).
          map { |r| [model, r.name] }
      end
    end

    # Every model that's a valid target for `model`'s polymorphic
    # `reflection_name` association - found via the inverse
    # `has_many/has_one ..., as: reflection_name` declaration on the target
    # model, not a hand-listed pairing. A target model with zero rows
    # referencing it yet is still found (this scans association
    # declarations, not live data), so a brand-new target type is covered
    # from the moment its `has_many ..., as: :target` line is added.
    def self.polymorphic_targets(model, reflection_name)
      all_models.select do |candidate|
        (candidate.reflect_on_all_associations(:has_many) +
         candidate.reflect_on_all_associations(:has_one)).any? do |r|
          r.options[:as] == reflection_name && r.klass == model
        end
      end
    end

    def self.all_models
      Rails.root.join("app/models").children.
        map { |path| path.basename.to_s }.
        grep(/^\w+\.rb$/).
        filter_map { |name| model_from_file(name) }
    end
    private_class_method :all_models

    def self.model_from_file(filename)
      model = filename.sub(/\.rb$/, "").classify.constantize
      model if model < ActiveRecord::Base
    rescue NameError
      nil
    end
    private_class_method :model_from_file

    def self.monomorphic_associations_for(model)
      poly_fks = polymorphic_foreign_keys(model)
      own = model.reflect_on_all_associations(:belongs_to).reject do |r|
        r.polymorphic? || typed_polymorphic_view?(r, poly_fks)
      end
      (own.map { |r| [model, r.name] } +
       version_associations_for(model, own)).uniq
    end
    private_class_method :monomorphic_associations_for

    def self.polymorphic_foreign_keys(model)
      model.reflect_on_all_associations(:belongs_to).
        select(&:polymorphic?).map(&:foreign_key)
    end
    private_class_method :polymorphic_foreign_keys

    def self.typed_polymorphic_view?(reflection, poly_fks)
      !reflection.polymorphic? && poly_fks.include?(reflection.foreign_key)
    end
    private_class_method :typed_polymorphic_view?

    # A `::Version` sibling (e.g. `Name::Version`) declares its own
    # `belongs_to` back to the base record and to `:user` - those are
    # real reflections on the Version class itself. It does NOT declare
    # `belongs_to` for the base model's other associations (e.g.
    # `Name#correct_spelling`), even though the versions table duplicates
    # some of those foreign-key columns for history purposes - so those
    # need to be "borrowed" from the base model's reflection, gated on the
    # matching column actually existing on the Version table (most of the
    # base model's associations aren't versioned at all).
    def self.version_associations_for(model, own_base_reflections)
      version_model = version_model_for(model)
      return [] unless version_model

      version_own = version_model.reflect_on_all_associations(:belongs_to)
      borrowed = borrowed_reflections(version_model, own_base_reflections,
                                      version_own)
      (version_own + borrowed).map { |r| [version_model, r.name] }
    end
    private_class_method :version_associations_for

    def self.version_model_for(model)
      version_model = "#{model.name}::Version".safe_constantize
      return nil unless version_model && version_model < ActiveRecord::Base
      return nil if version_model == model

      version_model
    end
    private_class_method :version_model_for

    # Base-model reflections not already declared on the Version class
    # itself, gated on the matching foreign-key column actually existing
    # on the Version's table (most of the base model's associations
    # aren't versioned at all).
    def self.borrowed_reflections(version_model, base_reflections, version_own)
      version_own_names = version_own.map(&:name)
      base_reflections.select do |r|
        version_own_names.exclude?(r.name) &&
          version_model.column_names.include?(r.foreign_key)
      end
    end
    private_class_method :borrowed_reflections
  end
end
