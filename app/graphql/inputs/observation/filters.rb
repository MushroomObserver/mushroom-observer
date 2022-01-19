# frozen_string_literal: true

module Inputs::Observation
  class Filters < Inputs::BaseInputObject
    description "Fields filtering an Observations query"
    # the name is usually inferred by class name but can be overwritten
    graphql_name "FilterObservationsInput"

    # argument :OR, [self], required: false
    # alternative: use select w/ autocomplete for taxa
    argument :name_id, Int, required: false
    # taxa: search for like string in name.text_name
    argument :name_like, String, required: false
    # use select w/ autocomplete and force an ID
    argument :user_id, Integer, required: false
    # alternative: search for string in user.name? expensive query
    argument :user_like, String, required: false
    # must search string for location, becase locations are not nested.
    argument :location_like, String, required: false # where == location.name
    argument :before, Boolean, required: false
    argument :when, GraphQL::Types::ISO8601Date, required: false
    argument :notes_like, String, required: false
    argument :with_image, Boolean, required: false # with, without, or either
    argument :with_specimen, Boolean, required: false # with, without or either
    argument :with_lichen, Boolean, required: false # with, without or either
    argument :order_by, Types::Enums::OrderBy, required: false
    argument :order, Types::Enums::Order, required: false
  end
end
