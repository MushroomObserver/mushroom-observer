# frozen_string_literal: true

class Name < AbstractModel
  class << self
    # This is used only by script/refresh_caches.  I have placed it here in
    # order to make it easily accessible to unit testing.  As a separate file,
    # it should never be loaded by the web server, so it's safe from causing
    # even more unnecessary bloat.  I think. -JPH 20210814
    def propagate_generic_classifications(dry_run: false)
      fixes = []
      accepted_names = build_accepted_names_lookup_table
      classifications = accepted_generic_classification_strings
      Name.select(:id, :synonym_id, :text_name, :classification).
        where(rank: 0..(Name.ranks[:Genus] - 1)).
        each do |name|
          old_class = old_classification(name)
          new_class = new_classification(name, accepted_names, classifications)
          next if old_class == new_class

          fixes << [name, old_class, new_class]
        end
      execute_propagation_fixes(fixes, dry_run)
    end

    private

    def old_classification(name)
      str = name.classification
      str.present? && str.strip || nil
    end

    def new_classification(name, accepted_names, classifications)
      accepted_text_name = accepted_names[name.synonym_id] || name.text_name
      genus = accepted_text_name.split.first
      str = classifications[genus]
      str.present? && str.strip || nil
    end

    def build_accepted_names_lookup_table
      Name.where(rank: 0..Name.ranks[:Genus], deprecated: false).
        where.not(synonym_id: nil).
        pluck(:synonym_id, :text_name).
        to_h
    end

    def accepted_generic_classification_strings
      Name.where(rank: Name.ranks[:Genus], deprecated: false).
        where("author NOT LIKE 'sensu lato%'").
        where("LENGTH(classification) > 2").
        pluck(:text_name, :classification).
        each_with_object({}) do |vals, classifications|
          text_name, classification = vals
          if classifications[text_name].present?
            warn("Multiple accepted non-sensu lato genera for #{text_name}!")
          else
            classifications[text_name] = classification
          end
        end
    end

    def hash_of_names_with_observations
      Hash[
        Observation.distinct.pluck(:text_name).collect do |text_name|
          [text_name, true]
        end
      ]
    end

    def execute_propagation_fixes(fixes, dry_run)
      bundles = {}
      used_names = hash_of_names_with_observations
      fixes.each_with_object([]) do |fix, msgs|
        name, old_class, new_class = fix
        bundles[new_class] = [] if bundles[new_class].blank?
        bundles[new_class] << name.id
        next unless used_names[name.text_name]

        msgs << describe_propagation_fix(name, old_class, new_class)
      end + execute_bundled_propagation_fixes(bundles, dry_run)
    end

    def execute_bundled_propagation_fixes(bundles, dry_run)
      bundles.each_with_object([]) do |bundle, msgs|
        classification, ids = bundle
        msgs << "Setting classifications for #{ids.join(",")}"
        Name.where(id: ids).update_all(classification: classification) \
          unless dry_run
      end
    end

    def describe_propagation_fix(name, old_class, new_class)
      if new_class.blank?
        "Stripping classification from #{name.text_name}"
      elsif old_class.blank?
        "Filling in classification for #{name.text_name}"
      else
        "Fixing classification of #{name.text_name}: " \
          "#{changes_in_classification_string(old_class, new_class)}"
      end
    end

    def changes_in_classification_string(old_class, new_class)
      Name.all_ranks.each_with_object([]) do |rank, msgs|
        old_name = grab_name_from_classification_string(old_class, rank)
        new_name = grab_name_from_classification_string(new_class, rank)
        msgs << "#{old_name} => #{new_name}" if old_name != new_name
      end.join(", ")
    end

    def grab_name_from_classification_string(str, rank)
      match = str.to_s.match(/#{rank}: _([^_]+)_/)
      match ? match[1] : "-"
    end
  end
end
