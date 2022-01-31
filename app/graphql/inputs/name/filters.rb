# frozen_string_literal: true

module Inputs::Name
  class Filters < Inputs::BaseInputObject
    description "Fields filtering an Names query"
    # the name is usually inferred by class name but can be overwritten
    graphql_name "FilterNamesInput"

    # argument :OR, [self], required: false
    # alternative: use select w/ autocomplete for taxa
    argument :name_id, Int, required: false
    # taxa: search for like string in name.text_name
    argument :name_like, String, required: false
    argument :synonym_id, Integer, required: false
    # use select w/ autocomplete and force an ID
    argument :user_id, Integer, required: false
    # alternative: search for string in user.name? expensive query
    argument :user_like, String, required: false
    argument :before, Boolean, required: false
    argument :when, GraphQL::Types::ISO8601Date, required: false
    argument :notes_like, String, required: false
    argument :order_by, Types::Enums::NamesOrderBy, required: false
    argument :order, Types::Enums::Order, required: false
    argument :rank, Integer, required: false
    argument :classification, String, required: false
    argument :deprecated, Boolean, required: false
    argument :num_views, Integer, required: false
  end
end
