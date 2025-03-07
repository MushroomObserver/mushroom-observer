# frozen_string_literal: true

module Name::Scopes # rubocop:disable Metrics/ModuleLength
  # This is using Concern so we can define the scopes in this included module.
  extend ActiveSupport::Concern

  # NOTE: To improve Coveralls display, avoid one-line stabby lambda scopes.
  # Two line stabby lambdas are OK, it's just the declaration line that will
  # always show as covered.
  included do # rubocop:disable Metrics/BlockLength
    # default ordering for index queries
    scope :index_order,
          -> { order(sort_name: :asc, id: :desc) }

    # NOTE: with_correct_spelling is tacked on to most Name queries.
    scope :misspellings, lambda { |boolish = :no|
      # if :either, returns all
      case boolish.to_sym
      when :no
        with_correct_spelling
      when :only
        with_incorrect_spelling
      end
    }
    scope :with_correct_spelling,
          -> { where(correct_spelling_id: nil) }
    scope :with_incorrect_spelling,
          -> { where.not(correct_spelling_id: nil) }
    scope :with_self_referential_misspelling,
          -> { where(Name[:correct_spelling_id].eq(Name[:id])) }
    scope :text_name_has,
          ->(phrase) { search_columns(Name[:text_name], phrase) }
    scope :search_name_has,
          ->(phrase) { search_columns(Name[:search_name], phrase) }

    scope :of_lichens, lambda { |bool = true|
      if bool.to_s.to_boolean == true
        where(Name[:lifeform].matches("%lichen%"))
      else
        not_lichens
      end
    }
    scope :not_lichens,
          -> { where(Name[:lifeform].does_not_match("% lichen %")) }

    scope :is_deprecated, lambda { |bool = true|
      if bool.to_s.to_boolean == true
        where(deprecated: true)
      else
        not_deprecated
      end
    }
    scope :not_deprecated,
          -> { where(deprecated: false) }

    scope :has_synonyms, lambda { |bool = true|
      if bool.to_s.to_boolean == true
        where.not(synonym_id: nil)
      else
        has_no_synonyms
      end
    }
    scope :has_no_synonyms,
          -> { where(synonym_id: nil) }

    scope :ok_for_export, lambda { |bool = true|
      if bool.to_s.to_boolean == true
        where(ok_for_export: true)
      else
        not_ok_for_export
      end
    }
    scope :not_ok_for_export,
          -> { where(ok_for_export: false) }

    scope :has_classification, lambda { |bool = true|
      if bool.to_s.to_boolean == true
        where(Name[:classification].not_blank)
      else
        has_no_classification
      end
    }
    scope :has_no_classification,
          -> { where(Name[:classification].blank) }
    scope :classification_has,
          ->(phrase) { search_columns(Name[:classification], phrase) }

    scope :has_author, lambda { |bool = true|
      if bool.to_s.to_boolean == true
        where(Name[:author].not_blank)
      else
        has_no_author
      end
    }
    scope :has_no_author,
          -> { where(Name[:author].blank) }
    scope :author_has,
          ->(phrase) { search_columns(Name[:author], phrase) }

    scope :has_citation, lambda { |bool = true|
      if bool.to_s.to_boolean == true
        where(Name[:citation].not_blank)
      else
        has_no_citation
      end
    }
    scope :has_no_citation,
          -> { where(Name[:citation].blank) }
    scope :citation_has,
          ->(phrase) { search_columns(Name[:citation], phrase) }

    scope :has_notes, lambda { |bool = true|
      if bool.to_s.to_boolean == true
        where(Name[:notes].not_blank)
      else
        has_no_notes
      end
    }
    scope :has_no_notes,
          -> { where(Name[:notes].blank) }
    scope :notes_has,
          ->(phrase) { search_columns(Name[:notes], phrase) }

    scope :names, lambda { |lookup:, **related_name_args|
      ids = lookup_names_by_name(lookup, related_name_args.compact)
      where(id: ids).distinct
    }
    ### Module Name::Taxonomy. Rank scopes take text values, e.g. "Genus"
    # Query's scope: rank at or between
    scope :rank, lambda { |min, max = min|
      min, max = min if min.is_a?(Array) && min.size == 2
      return with_rank(min) if min == max

      where(Name[:rank].in(rank_range(min, max)))
    }
    scope :with_rank,
          ->(rank) { where(rank: ranks[rank]) if rank }
    scope :with_rank_below, lambda { |rank|
      where(Name[:rank] < ranks[rank]) if rank
    }
    scope :with_rank_and_name_in_classification, lambda { |rank, text_name|
      where(Name[:classification].matches("%#{rank}: _#{text_name}_%"))
    }
    scope :with_rank_at_or_below_genus, lambda {
      where((Name[:rank] <= ranks[:Genus]).or(Name[:rank].eq(ranks[:Group])))
    }
    scope :with_rank_above_genus, lambda {
      where(Name[:rank] > ranks[:Genus]).
        where(Name[:rank].not_eq(ranks[:Group]))
    }
    scope :subtaxa_of_genus_or_below, lambda { |text_name|
      # Note the space " " difference from :text_name_has scope
      with_correct_spelling.where(Name[:text_name].matches("#{text_name} %"))
    }
    scope :subtaxa_of, lambda { |name, exclude_original = true|
      name = find_by(text_name: name) if name.is_a?(String)
      scope = if name.at_or_below_genus?
                # Subtaxa can be determined from the text_name
                subtaxa_of_genus_or_below(name.text_name)
              else
                # Need to examine the classification strings
                with_rank_and_name_in_classification(name.rank, name.text_name)
              end
      scope = scope.or(Name.where(id: name.id)) unless exclude_original == true
      scope
    }
    # "Immediate" has a vaguer meaning at and below Genus
    scope :immediate_subtaxa_of, lambda { |name, exclude_original = true|
      name = find_by(text_name: name) if name.is_a?(String)
      scope = if ranks_above_genus.include?(name.rank)
                subtaxa_of(name).with_rank(ranks[name.rank] - 1)
              else
                subtaxa_of(name)
              end
      scope = scope.or(Name.where(id: name.id)) unless exclude_original == true
      scope
    }
    ### Pattern Search
    scope :include_synonyms_of, lambda { |name|
      with_correct_spelling.where(id: name.synonyms.map(&:id))
    }
    # alias of `include_subtaxa_of`
    scope :in_clade,
          ->(name) { include_subtaxa_of(name) }
    scope :include_subtaxa_of, lambda { |name|
      name = find_by(text_name: name) if name.is_a?(String)
      # names = [name] + subtaxa_of(name)
      # with_correct_spelling.where(id: names.map(&:id))
      subtaxa_of(name, false) # include original name
    }
    scope :include_immediate_subtaxa_of, lambda { |name|
      name = find_by(text_name: name) if name.is_a?(String)
      # names = [name] + immediate_subtaxa_of(name)
      # with_correct_spelling.where(id: names.map(&:id))
      immediate_subtaxa_of(name, false) # include original name
    }
    scope :include_subtaxa_above_genus,
          ->(name) { include_subtaxa_of(name).with_rank_above_genus }

    # A search of all searchable Name fields, concatenated.
    scope :search_content, lambda { |phrase|
      cols = Name.searchable_columns + Name[:classification]
      search_columns(cols, phrase)
    }
    # A more comprehensive search of Name fields, plus comments/descriptions.
    scope :search_content_and_associations, lambda { |phrase|
      fields = Name.search_content(phrase).map(&:id)
      comments = Name.comments_has(phrase).map(&:id)
      descs = Name.description_has(phrase).map(&:id)
      where(id: fields + comments + descs).distinct
    }
    # This is what's called by advanced_search
    scope :advanced_search, lambda { |phrase|
      fields = Name.search_columns(Name[:search_name], phrase).map(&:id)
      comments = Name.comments_has(phrase).map(&:id)
      where(id: fields + comments).distinct
    }
    # This is what's called by pattern_search
    scope :pattern, lambda { |phrase|
      cols = Name.searchable_columns + NameDescription.searchable_columns
      joins_default_descriptions.search_columns(cols, phrase).distinct
    }
    # https://stackoverflow.com/a/77064711/3357635
    # AR's assumed join condition is `Name[:id].eq(NameDescription[:name_id])`
    # but we want the converse. It is a bit complicated to write a left outer
    # join in AR that joins on a non-standard condition, so here it is:
    scope :joins_default_descriptions, lambda {
      joins(
        Name.arel_table.
        join(NameDescription.arel_table, Arel::Nodes::OuterJoin).
        on(Name[:description_id].eq(NameDescription[:id])).join_sources
      )
    }

    scope :has_comments, lambda { |bool = true|
      if bool.to_s.to_boolean == true
        joins(:comments).distinct
      else
        has_no_comments
      end
    }
    scope :has_no_comments,
          -> { where.not(id: Name.has_comments) }
    scope :comments_has, lambda { |phrase|
      joins(:comments).merge(Comment.search_content(phrase)).distinct
    }

    scope :has_descriptions, lambda { |bool = true|
      presence_condition(Name[:description_id], bool:)
    }
    scope :need_description, lambda {
      has_descriptions(false).joins(:observations).distinct.
        group(:name_id).order(Observation[:name_id].count.desc, Name[:id].desc)
    }
    scope :description_has, lambda { |phrase|
      joins(:descriptions).
        merge(NameDescription.content_has(phrase)).distinct
    }
    scope :has_description_in_project, lambda { |project|
      joins(descriptions: :project).
        merge(NameDescription.where(project: project)).distinct
    }
    scope :has_description_created_by, lambda { |user|
      joins(:descriptions).
        merge(NameDescription.where(user: user)).distinct
    }
    scope :has_description_reviewed_by, lambda { |user|
      joins(:descriptions).
        merge(NameDescription.where(reviewer: user)).distinct
    }
    scope :has_description_of_type, lambda { |source|
      # Check that it's a valid source type (string enum value)
      return none if Description::ALL_SOURCE_TYPES.exclude?(source)

      joins(:descriptions).
        merge(NameDescription.types(source)).distinct
    }
    scope :has_description_classification_differing, lambda {
      joins(:description).
        where(rank: 0..Name.ranks[:Genus]).
        where(NameDescription[:classification].not_eq(Name[:classification])).
        where(NameDescription[:classification].not_blank).distinct
    }

    scope :on_species_lists, lambda { |species_lists|
      species_list_ids = lookup_species_lists_by_name(species_lists)
      joins(observations: :species_list_observations).
        merge(SpeciesListObservation.where(species_list: species_list_ids)).
        distinct
    }
    # Accepts region string, location_id, or Location instance
    scope :at_locations, lambda { |locations|
      location_ids = lookup_regions_by_name(locations)
      joins(:observations).
        where(observations: { location: location_ids }).distinct
    }
    # Names with Observations whose lat/lon are in a box
    # Pass kwargs (:north, :south, :east, :west), any order
    scope :in_box, lambda { |**args|
      joins(:observations).merge(Observation.in_box(**args)).distinct
    }

    ### Specialized Scopes for Name::Create
    # Get list of Names that are potential matches when creating a new name.
    # Takes results of Name.parse_name.  Used by NameController#create_name.
    # Three cases:
    #
    #   1. group with author       - only accept exact matches
    #   2. nongroup with author    - match names with correct or no author
    #   3. any name without author - ignore authors when matching names
    #
    # If the user provides an author, but the only match has no author, then we
    # just need to add an author to the existing Name.  If the user didn't give
    # an author, but there are matches with an author, then it already exists
    # and we should just ignore the request.
    #
    scope :matching_desired_new_parsed_name, lambda { |parsed_name|
      if parsed_name.rank == "Group"
        where(search_name: parsed_name.search_name)
      elsif parsed_name.author.empty?
        where(text_name: parsed_name.text_name)
      else
        where(text_name: parsed_name.text_name).
          where(author: [parsed_name.author, ""])
      end
    }
    scope :show_includes, lambda {
      strict_loading.includes(
        { comments: :user },
        :correct_spelling,
        { description: [:authors, :reviewer] },
        { descriptions: [:authors, :editors, :reviewer, :writer_groups] },
        { interests: :user },
        :misspellings,
        # { namings: [:user] },
        # { observations: [:location, :thumb_image, :user] },
        :rss_log,
        { synonym: :names },
        :user,
        :versions
      )
    }
  end

  module ClassMethods
    # class methods here, `self` included
    def rank_range(min, max)
      all_ranks = Name.all_ranks
      a = all_ranks.index(min) || 0
      b = all_ranks.index(max) || (all_ranks.length - 1)
      a, b = b, a if a > b # reverse if wrong order
      all_ranks[a..b].map { |r| Name.ranks[r] } # values start at 1
    end
  end
end
