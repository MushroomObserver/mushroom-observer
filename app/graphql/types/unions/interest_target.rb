module Types::Unions
  class InterestTarget < Types::BaseUnion
    description "Targets of an Interest"

    possible_types Types::Models::Location,
                   Types::Models::Name,
                   Types::Models::Observation,
                   Types::Models::Project,
                   Types::Models::SpeciesList
  end
end
