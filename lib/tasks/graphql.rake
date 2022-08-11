# frozen_string_literal: true

# Use: rake graphql:dump_schema
# Note that it's possible to make dumps of schema for different environments,
# for example public/private

namespace :graphql do
  desc "Write a dump of the entire GraphQL Schema"
  task(dump_schema: :environment) do
    # Get a string containing the definition in GraphQL IDL:
    schema_defn = MushroomObserverSchema.to_definition
    # Choose a place to write the schema dump:
    schema_path = "public/graphql/schema.graphql"
    # Write the schema dump to that file:
    File.write(Rails.root.join(schema_path), schema_defn)
    puts "Updated #{schema_path}"
  end
end
