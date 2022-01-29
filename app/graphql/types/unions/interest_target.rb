# frozen_string_literal: true

module Types::Unions
  class InterestTarget < Types::BaseUnion
    description "Targets of an Interest"

    possible_types Types::Models::LocationType,
                   Types::Models::NameType,
                   Types::Models::ObservationType,
                   Types::Models::ProjectType,
                   Types::Models::SpeciesListType
  end
end
