# frozen_string_literal: true

#  ==== Scopes
#  created_at("yyyy-mm-dd", "yyyy-mm-dd")
#  updated_at("yyyy-mm-dd", "yyyy-mm-dd")
#  deprecated
#  has_description
#  with_correct_spelling
#  with_incorrect_spelling
#  with_self_referential_misspelling
#  has_synonyms
#  ok_for_export
#  rank(ranks)
#  with_rank(rank)
#  with_rank_below(rank)
#  with_rank_and_name_in_classification(rank, text_name)
#  with_rank_at_or_below_genus
#  with_rank_above_genus
#  subtaxa_of_genus_or_below(genus)
#  subtaxa_of(name)
#  include_synonyms_of(name)
#  clade(name)
#  text_name_has(text_name)
#  search_name_has(phrase)
#  has_classification
#  classification_has(classification)
#  has_author
#  author_has(author)
#  has_citation
#  citation_has(citation)
#  has_notes
#  notes_has(notes)
#  has_comments
#  comments_has(summary)
#  species_lists(species_list)
#  locations(location)
#  in_box(north:, south:, east:, west:)
#
module Name::Scopes
  # This is using Concern so we can define the scopes in this included module.
  extend ActiveSupport::Concern

  # NOTE: To improve Coveralls display, avoid one-line stabby lambda scopes.
  # Two line stabby lambdas are OK, it's just the declaration line that will
  # always show as covered.
  included do
    # default ordering for index queries
    scope :order_by_default,
          -> { order_by(::Query::Names.default_order) }

    scope :names, lambda { |lookup:, **related_name_args|
      ids = Lookup::Names.new(lookup, related_name_args.compact).ids
      return none unless ids

      where(id: ids).with_correct_spelling.distinct
    }
    scope :text_name_has,
          ->(phrase) { search_columns(Name[:text_name], phrase) }
    # scope :search_name_has,
    #       ->(phrase) { search_columns(Name[:search_name], phrase) }

    # NOTE: with_correct_spelling is tacked on to most Name queries.
    scope :misspellings, lambda { |boolish = :no|
      # if :either, returns all
      case boolish.to_sym
      when :no
        where(correct_spelling_id: nil)
      when :only
        where.not(correct_spelling_id: nil)
      when :either
        all
      end
    }
    scope :with_correct_spelling,
          -> { misspellings(:no) }
    scope :with_incorrect_spelling,
          -> { misspellings(:only) }
    scope :with_self_referential_misspelling,
          -> { where(Name[:correct_spelling_id].eq(Name[:id])) }

    # Query parses "yes" and "no", "on" and "off" to boolean. nil ignored.
    scope :lichen, lambda { |bool = true|
      case bool
      when true
        where(Name[:lifeform].matches("%lichen%"))
      when false
        where(Name[:lifeform].does_not_match("% lichen %"))
      end
    }

    scope :deprecated,
          ->(bool = true) { boolean_condition(Name[:deprecated], bool:) }
    scope :not_deprecated,
          -> { where(deprecated: false) }

    scope :has_synonyms,
          ->(bool = true) { presence_condition(Name[:synonym_id], bool:) }

    scope :ok_for_export,
          ->(bool = true) { where(ok_for_export: bool) }

    scope :has_author,
          ->(bool = true) { not_blank_condition(Name[:author], bool:) }
    scope :author_has,
          ->(phrase) { search_columns(Name[:author], phrase) }

    scope :has_citation,
          ->(bool = true) { not_blank_condition(Name[:citation], bool:) }
    scope :citation_has,
          ->(phrase) { search_columns(Name[:citation], phrase) }

    scope :has_classification,
          ->(bool = true) { not_blank_condition(Name[:classification], bool:) }
    scope :classification_has,
          ->(phrase) { search_columns(Name[:classification], phrase) }

    scope :has_notes,
          ->(bool = true) { not_blank_condition(Name[:notes], bool:) }
    scope :notes_has,
          ->(phrase) { search_columns(Name[:notes], phrase) }

    ### Module Name::Taxonomy. Rank scopes take text values, e.g. "Genus"
    # Query's scope: rank at or between
    scope :rank, lambda { |min, max = nil|
      min, max = min if min.is_a?(Array)
      return with_rank(min) if min.present? && max.blank?

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
    scope :subtaxa_of, lambda { |names, excl = true|
      names(lookup: names, include_subtaxa: true, exclude_original_names: excl).
        misspellings(:no)
    }
    # "Immediate" has a vaguer meaning at and below Genus
    scope :include_immediate_subtaxa_of, lambda { |name|
      # This should be equivalent, but it misses subtaxa with rank: "Variety".
      # (Changed to accept plural names.)
      # immediate_subtaxa_of(names, false)
      name = find_by(text_name: name) if name.is_a?(String)
      immediate_subtaxa_of(name, false) # include original name
    }
    scope :immediate_subtaxa_of, lambda { |name, exclude_original = true|
      # This should be equivalent, but it misses subtaxa with rank: "Variety".
      # (Changed to accept plural names.)
      # names(lookup: names, include_immediate_subtaxa: true,
      #       exclude_original_names: exclude_original)
      name = find_by(text_name: name) if name.is_a?(String)
      scope = if ranks_above_genus.include?(name.rank)
                subtaxa_of(name).rank(ranks[name.rank] - 1)
              else
                subtaxa_of(name)
              end
      unless exclude_original == true
        # Add `distinct` to balance `or` clause: subtaxa_of calls `distinct`
        scope = scope.or(Name.where(id: name.id).distinct)
      end
      scope
    }
    ### Pattern Search
    scope :include_synonyms_of, lambda { |name|
      with_correct_spelling.where(id: name.synonyms.map(&:id))
    }

    # This should really be clades/clade, but changing user prefs/filters and
    # autocompleters is very involved, requires migration and script.
    scope :clade, lambda { |clades|
      clades = [clades].flatten
      clades.map! { |val| one_clade(val) }
      or_clause(*clades).distinct
    }
    scope :one_clade, lambda { |names|
      names(lookup: names, include_subtaxa: true).misspellings(:no)
    }
    # scope :clade_above_genus,
    #       ->(name) { clade(name).with_rank_above_genus }

    # # A search of all searchable Name fields, concatenated.
    # scope :search_content, lambda { |phrase|
    #   cols = Name.searchable_columns + Name[:classification]
    #   search_columns(cols, phrase)
    # }
    # scope :search_name,
    #       ->(phrase) { search_columns(Name[:search_name], phrase) }
    # # A more comprehensive search of Name fields, plus comments/descriptions.
    # scope :search_content_and_associations, lambda { |phrase|
    #   fields = Name.search_content(phrase).map(&:id)
    #   comments = Name.comments_has(phrase).map(&:id)
    #   descs = Name.description_query(content_has: phrase).map(&:id)
    #   where(id: fields + comments + descs).distinct
    # }
    # This is what's called by advanced_search
    # scope :advanced_search, lambda { |phrase|
    #   fields = Name.search_columns(Name[:search_name], phrase).map(&:id)
    #   comments = Name.comments_has(phrase).map(&:id)
    #   where(id: fields + comments).distinct
    # }
    # This is what's called by pattern_search
    scope :pattern, lambda { |phrase|
      search_columns(Name.searchable_columns, phrase)
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

    # Query just ignores `has_descriptions(false)`, so for now we will here too.
    scope :has_descriptions, lambda { |bool = true|
      return all unless bool

      joins(:descriptions).distinct
    }
    # This is the scope we're more likely interested in
    scope :has_default_description,
          ->(bool = true) { presence_condition(Name[:description_id], bool:) }
    # Called by a special index page
    scope :needs_description, lambda { |bool = true|
      return all unless bool

      has_default_description(false).joins(:observations).distinct.
        group(:name_id).order(Observation[:name_id].count.desc, Name[:id].desc)
    }
    # used by Name::Taxonomy
    scope :has_description_classification_differing, lambda {
      joins(:description).
        where(rank: 0..Name.ranks[:Genus]).
        where(NameDescription[:classification].not_eq(Name[:classification])).
        where(NameDescription[:classification].not_blank).distinct
    }

    # Query just ignores `has_observations(false)`, so for now we will here too.
    scope :has_observations, lambda { |bool = true|
      return all unless bool

      joins(:observations).distinct
    }
    scope :species_lists, lambda { |species_lists|
      species_list_ids = Lookup::SpeciesLists.new(species_lists).ids
      joins(observations: :species_list_observations).
        merge(SpeciesListObservation.where(species_list: species_list_ids)).
        distinct
    }
    # Accepts region string, location_id, or Location instance
    scope :locations, lambda { |locations|
      return none if locations.blank?

      joins(:observations).merge(Observation.locations(locations)).distinct
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

    # Pull any :names param out to the main Name query.
    # Skip it in subqueries, where it would be inefficient and redundant.
    # (We don't want to query indirectly for "Names of Observations of Names".)
    scope :description_query, lambda { |hash|
      scope = all
      names_params = hash.delete(:names)
      scope = scope.names(**names_params) if names_params.present?
      scope.joins(:descriptions).subquery(:NameDescription, hash)
    }
    # Likewise here, filter :names, :clade or :lichen directly, not the
    # circuitous way via Observations.
    scope :observation_query, lambda { |hash|
      scope = all
      names_params = hash.delete(:names)
      scope = scope.names(**names_params) if names_params.present?
      clades = hash.delete(:clade)
      scope = scope.clade(clades) if clades.present?
      lichens = hash.delete(:lichen)
      scope = scope.lichen(lichens) unless lichens.nil?
      # Lichen unexpectedly unscopes `distinct`, other scopes don't. IDK why.
      scope.joins(:observations).distinct.subquery(:Observation, hash)
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
