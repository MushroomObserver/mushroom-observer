# frozen_string_literal: true

module Name::Scopes
  # This is using Concern so we can define the scopes in this included module.
  extend ActiveSupport::Concern

  # NOTE: To improve Coveralls display, avoid one-line stabby lambda scopes.
  # Two line stabby lambdas are OK, it's just the declaration line that will
  # always show as covered.
  included do # rubocop:disable Metrics/BlockLength
    # default ordering for index queries
    scope :index_order,
          -> { order(sort_name: :asc, id: :desc) }

    scope :of_lichens, lambda {
      with_correct_spelling.where(Name[:lifeform].matches("%lichen%"))
    }
    scope :not_lichens, lambda {
      with_correct_spelling.
        where(Name[:lifeform].does_not_match("% lichen %"))
    }
    scope :deprecated,
          -> { with_correct_spelling.where(deprecated: true) }
    scope :not_deprecated,
          -> { with_correct_spelling.where(deprecated: false) }
    ### Module Name::Spelling
    scope :with_correct_spelling,
          -> { where(correct_spelling_id: nil) }
    scope :with_incorrect_spelling,
          -> { where.not(correct_spelling_id: nil) }
    scope :with_self_referential_misspelling,
          -> { where(Name[:correct_spelling_id].eq(Name[:id])) }
    scope :with_synonyms,
          -> { with_correct_spelling.where.not(synonym_id: nil) }
    scope :without_synonyms,
          -> { with_correct_spelling.where(synonym_id: nil) }
    scope :ok_for_export,
          -> { with_correct_spelling.where(ok_for_export: true) }

    ### Module Name::Taxonomy. Rank scopes take text values, e.g. "Genus"
    scope :with_rank,
          ->(rank) { with_correct_spelling.where(rank: ranks[rank]) if rank }
    scope :with_rank_between, lambda { |min, max = min|
      return with_rank(min) if min == max

      with_correct_spelling.where(Name[:rank].in(rank_range(min, max)))
    }
    scope :with_rank_below, lambda { |rank|
      with_correct_spelling.where(Name[:rank] < ranks[rank]) if rank
    }
    scope :with_rank_and_name_in_classification, lambda { |rank, text_name|
      with_correct_spelling.
        where(Name[:classification].matches("%#{rank}: _#{text_name}_%"))
    }
    # FIXME: Exception for Sequence with_name queries:
    # for some reason they accept misspelled names.
    scope :with_rank_at_or_below_genus, lambda {
      where((Name[:rank] <= ranks[:Genus]).or(Name[:rank].eq(ranks[:Group])))
    }
    scope :with_rank_above_genus, lambda {
      with_correct_spelling.where(Name[:rank] > ranks[:Genus]).
        where(Name[:rank].not_eq(ranks[:Group]))
    }
    scope :subtaxa_of_genus_or_below, lambda { |text_name|
      # Note the space " " difference from :text_name_contains scope
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

    scope :text_name_contains, lambda { |phrase|
      with_correct_spelling.search_columns(Name[:text_name], phrase)
    }
    scope :search_name_contains, lambda { |phrase|
      with_correct_spelling.search_columns(Name[:search_name], phrase)
    }
    scope :with_classification,
          -> { with_correct_spelling.where(Name[:classification].not_blank) }
    scope :without_classification,
          -> { with_correct_spelling.where(Name[:classification].blank) }
    scope :classification_contains, lambda { |phrase|
      with_correct_spelling.search_columns(Name[:classification], phrase)
    }
    scope :with_author,
          -> { with_correct_spelling.where(Name[:author].not_blank) }
    scope :without_author,
          -> { with_correct_spelling.where(Name[:author].blank) }
    scope :author_contains, lambda { |phrase|
      with_correct_spelling.search_columns(Name[:author], phrase)
    }
    scope :with_citation,
          -> { with_correct_spelling.where(Name[:citation].not_blank) }
    scope :without_citation,
          -> { with_correct_spelling.where(Name[:citation].blank) }
    scope :citation_contains, lambda { |phrase|
      with_correct_spelling.search_columns(Name[:citation], phrase)
    }
    scope :with_notes,
          -> { with_correct_spelling.where(Name[:notes].not_blank) }
    scope :without_notes,
          -> { with_correct_spelling.where(Name[:notes].blank) }
    scope :notes_contain, lambda { |phrase|
      with_correct_spelling.search_columns(Name[:notes], phrase)
    }
    # A search of all searchable Name fields, concatenated.
    scope :search_content, lambda { |phrase|
      with_correct_spelling.search_columns(Name.searchable_columns, phrase)
    }
    # A more comprehensive search of Name fields, plus descriptions/comments.
    scope :search_content_and_associations, lambda { |phrase|
      fields = Name.search_content(phrase).map(&:id)
      comments = Name.comments_contain(phrase).map(&:id)
      descs = Name.description_contains(phrase).map(&:id)
      where(id: fields + comments + descs).distinct
    }

    scope :with_comments,
          -> { with_correct_spelling.joins(:comments).distinct }
    scope :without_comments,
          -> { with_correct_spelling.where.not(id: with_comments) }
    scope :comments_contain, lambda { |phrase|
      with_correct_spelling.joins(:comments).
        merge(Comment.search_content(phrase))
    }

    scope :with_description,
          -> { with_correct_spelling.where.not(description_id: nil) }
    scope :without_description,
          -> { with_correct_spelling.where(description_id: nil) }
    # Names needing descriptions
    # In the template, order scope `description_needed` by most frequently used:
    #   Name.description_needed.group(:name_id).reorder(Arel.star.count.desc)
    scope :description_needed,
          -> { without_description.joins(:observations).distinct }
    scope :description_contains, lambda { |phrase|
      with_correct_spelling.joins(:descriptions).
        merge(NameDescription.search_content(phrase)).distinct
    }
    scope :with_description_in_project, lambda { |project|
      with_correct_spelling.joins(descriptions: :project).
        merge(NameDescription.where(project: project))
    }
    scope :with_description_created_by, lambda { |user|
      with_correct_spelling.
        joins(:descriptions).merge(NameDescription.where(user: user))
    }
    scope :with_description_reviewed_by, lambda { |user|
      with_correct_spelling.
        joins(:descriptions).merge(NameDescription.where(reviewer: user))
    }
    scope :with_description_of_type, lambda { |source|
      # Check that it's a valid source type (string enum value)
      return none if Description::ALL_SOURCE_TYPES.exclude?(source)

      with_correct_spelling.
        joins(:descriptions).merge(NameDescription.where(source_type: source))
    }
    scope :with_description_classification_differing, lambda {
      with_correct_spelling.joins(:description).
        where(rank: 0..Name.ranks[:Genus]).
        where(NameDescription[:classification].not_eq(Name[:classification])).
        where(NameDescription[:classification].not_blank)
    }

    scope :on_species_lists, lambda { |species_lists|
      species_list_ids = lookup_species_lists_by_name(species_lists)
      with_correct_spelling.joins(observations: :species_list_observations).
        merge(SpeciesListObservation.where(species_list: species_list_ids)).
        distinct
    }
    # Accepts region string, location_id, or Location instance
    scope :at_locations, lambda { |locations|
      location_ids = lookup_regions_by_name(locations)
      with_correct_spelling.
        joins(:observations).where(observations: { location: location_ids }).
        distinct
    }
    # Names with Observations whose lat/lon are in a box
    # Pass kwargs (:north, :south, :east, :west), any order
    scope :in_box, lambda { |**args|
      with_correct_spelling.
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
