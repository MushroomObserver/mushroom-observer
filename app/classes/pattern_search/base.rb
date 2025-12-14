# frozen_string_literal: true

module PatternSearch
  # Base class for PatternSearch; handles everything plus build_query
  class Base
    attr_accessor :errors, :parser, :query_params, :query

    def initialize(string)
      self.errors = []
      self.parser = PatternSearch::Parser.new(string)
      build_query
      model_symbol = model.name.to_sym
      if query_params.include?(:pattern) && model_symbol == :Name
        pat = query_params[:pattern]
        query_params[:pattern] = ::Name.parse_name(pat)&.search_name || pat
      end
      self.query = Query.lookup(model_symbol, query_params)
    rescue Error => e
      errors << e
    end

    def build_query
      self.query_params = {}
      parser.terms.each do |term|
        if term.var == :pattern
          query_params[:pattern] = term.parse_pattern
        elsif (param = lookup_param(term.var))
          query_param, parse_method = param
          query_params[query_param] = term.send(parse_method)
        else
          raise(
            PatternSearch::BadTermError.new(term: term,
                                            type: model.type_tag,
                                            help: help_message)
          )
        end
      end
    end

    def put_names_and_modifiers_in_hash
      modifiers = [:include_subtaxa, :include_synonyms,
                   :include_immediate_subtaxa, :exclude_original_names,
                   :include_all_name_proposals, :exclude_consensus]
      lookup, include_subtaxa, include_synonyms,
      include_immediate_subtaxa, exclude_original_names,
      include_all_name_proposals, exclude_consensus =
        query_params.values_at(:names, *modifiers)
      names = { lookup:, include_subtaxa:, include_synonyms:,
                include_immediate_subtaxa:, exclude_original_names:,
                include_all_name_proposals:, exclude_consensus: }
      return if names.compact.blank?

      query_params[:names] = names.compact
      query_params.except!(*modifiers)
    end

    def put_nsew_params_in_box
      north, south, east, west = query_params.values_at(:north, :south, :east,
                                                        :west)
      box = { north:, south:, east:, west: }
      return if box.compact.blank?

      box = validate_box(box)
      query_params[:in_box] = box
      query_params.except!(:north, :south, :east, :west)
    end

    def validate_box(box)
      validator = Mappable::Box.new(**box)
      return box if validator.valid?

      check_for_missing_box_params
      # Just fix the box if they've got it swapped
      if query_params[:south] > query_params[:north]
        box = box.merge(north: query_params[:south],
                        south: query_params[:north])
      end
      box
    end

    def check_for_missing_box_params
      debugger
      [:north, :south, :east, :west].each do |term|
        next if query_params[term].present?

        raise(PatternSearch::MissingValueError.new(var: term))
      end
    end

    def help_message
      :pattern_search_terms_short_help.l
    end

    def self.terms_help
      params.keys.map do |arg|
        "* *#{arg}*: #{:"#{model.type_tag}_term_#{arg}".l}"
      end.join("\n")
    end

    def lookup_param(var)
      # See if this var matches an English parameter name first.
      return params[var] if params[var].present?

      # Then check if any of the translated parameter names match.
      params.each_key do |key|
        return params[key] if var.to_s == :"search_term_#{key}".l.tr(" ", "_")
      end
      nil
    end
  end
end
