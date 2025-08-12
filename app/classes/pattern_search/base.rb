# frozen_string_literal: true

module PatternSearch
  # Base class for PatternSearch; handles everything plus build_query
  class Base
    attr_accessor :errors, :parser, :args, :query

    def initialize(string)
      self.errors = []
      self.parser = PatternSearch::Parser.new(string)
      build_query
      real_model = model.name.to_sym
      if args.include?(:pattern) && real_model == :Name
        pat = args[:pattern]
        args[:pattern] = ::Name.parse_name(pat)&.search_name || pat
      end
      self.query = Query.lookup(real_model, args)
    rescue Error => e
      errors << e
    end

    def build_query
      self.args = {}
      parser.terms.each do |term|
        if term.var == :pattern
          args[:pattern] = term.parse_pattern
        elsif (param = lookup_param(term.var))
          query_param, parse_method = param
          args[query_param] = term.send(parse_method)
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
        args.values_at(:names, *modifiers)
      names = { lookup:, include_subtaxa:, include_synonyms:,
                include_immediate_subtaxa:, exclude_original_names:,
                include_all_name_proposals:, exclude_consensus: }
      return if names.compact.blank?

      args[:names] = names.compact
      args.except!(*modifiers)
    end

    def help_message
      "#{:pattern_search_terms_help.l}\n#{self.class.terms_help}"
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
