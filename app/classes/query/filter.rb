# frozen_string_literal: true

#
#  = Filter
#
#  This class describes a set of content-filtering parameters which can be
#  applied to Query's.
#
#  == Class methods
#
#  all::             Array of all available content filters.
#  find::            Look up a named filter.
#  by_model::        Array of content filters applicable to a given model.
#
#  == Instance methods
#
#  sym::             Name of filter (symbol).
#  name::            Name of filter (translation string).
#  models::          Array of models this filter can be applied to.
#  applicable_to_model?:: Can this filter be applied to a model query?
#  on?::             Test if a filter is turned on.
#
#  == Adding new filters
#
#  * Add tests to test/models/query_test.rb
#  * Add tests to test/integration/filter_test.rb
#  * Supplement fixtures as needed by added tests
#  * Add a filter definition below
#  * In config/locales/en.txt define text to be displayed in
#    account/preferences/edit and search/advanced pages
#    (search for "filters_has_images")
#  * Supplement app/classes/query/initializers/xxx_filters.rb
#
class Query::Filter
  attr_accessor :sym, :models, :name

  def initialize(opts)
    opts.each do |key, val|
      send(:"#{key}=", val)
    end
  end

  # Array of all available filters.
  def self.all
    [
      WithImages.new,
      WithSpecimen.new,
      Lichen.new,
      Region.new,
      Clade.new
    ].freeze
  end

  # Lookup a filter by name (symbol).
  def self.find(key)
    all.find { |fltr| fltr.sym == key }
  end

  def self.by_model(model)
    all.select { |fltr| fltr.models.include?(model) }
  end

  def applicable_to_model?(model)
    models.include?(model)
  end
end
