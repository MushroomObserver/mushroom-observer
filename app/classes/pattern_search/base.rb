# frozen_string_literal: true

module PatternSearch
  # Base class for PatternSearch; handles everything but build_query
  class Base
    attr_accessor :errors, :parser, :flavor, :args, :query, :form_params

    def initialize(string)
      self.errors = []
      self.parser = PatternSearch::Parser.new(string)
      self.form_params = make_terms_available_to_faceted_form
      build_query
      self.query = Query.lookup(model.name.to_sym, flavor, args)
    rescue Error => e
      errors << e
    end

    # rubocop:disable Metrics/AbcSize
    def build_query
      self.flavor = :all
      self.args   = {}
      parser.terms.each do |term|
        if term.var == :pattern
          self.flavor = :pattern_search
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
    # rubocop:enable Metrics/AbcSize

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

    # Build a hash so we can populate the form fields with from the values from
    # the saved search string. Turn ranges into ranges, and dates into dates.
    # NOTE: The terms may be translated! We have to look up the param names that
    # the translations map to.
    # rubocop:disable Metrics/AbcSize
    def make_terms_available_to_faceted_form
      parser.terms.each_with_object({}) do |term, hash|
        param = lookup_param_name(term.var)
        if fields_with_dates.include?(param)
          # term is what the user typed in, not the parsed value.
          start, range = check_for_date_range(term)
          hash[param] = start
          hash[:"#{param}_range"] = range if range
        elsif fields_with_numeric_range.include?(param)
          start, range = check_for_numeric_range(term)
          hash[param] = start
          hash[:"#{param}_range"] = range if range
        else
          hash[param] = term.vals.join(", ")
        end
      end
    end
    # rubocop:enable Metrics/AbcSize

    def lookup_param_name(var)
      # See if this var matches an English parameter name first.
      return var if params[var].present?

      # Then check if any of the translated parameter names match.
      params.each_key do |key|
        return key if var.to_s == :"search_term_#{key}".l.tr(" ", "_")
      end
      nil
    end

    # The string could be a date string like "2010-01-01", or a range string
    # like "2010-01-01-2010-01-31", or "2023-2024", or "08-10".
    # If it is a range, return the two dates.
    def check_for_date_range(term)
      start, range = term.parse_date_range
      # dates.map! do |date|
      #   next if date.blank?

      #   date.split("-").map(&:to_i)
      # end

      # start = dates[0] if dates[0]
      # range = dates[1] if dates[1]

      range = nil if start == range

      [start, range]
    end

    def check_for_numeric_range(term)
      bits = term.vals[0].split("-")

      if bits.size == 2
        [bits[0].to_i, bits[1].to_i]
      else
        [term.vals[0], nil]
      end
    end

    # These are set in the subclasses, but seem stable enough to be here.
    def fields_with_dates
      [:when, :created, :modified].freeze
    end

    def fields_with_numeric_range
      [:rank].freeze
    end
  end
end
