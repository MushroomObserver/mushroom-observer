# frozen_string_literal: true

# Be sure to restart your server when you modify this file.

# Add new inflection rules using the following format. Inflections
# are locale specific, and you may define rules for as many different
# locales as you wish. All of these examples are active by default:
# ActiveSupport::Inflector.inflections(:en) do |inflect|
#   inflect.plural /^(ox)$/i, '\1en'
#   inflect.singular /^(ox)en/i, '\1'
#   inflect.irregular 'person', 'people'
#   inflect.uncountable %w( fish sheep )
# end

# These inflection rules are supported but not enabled by default:
# ActiveSupport::Inflector.inflections(:en) do |inflect|
#   inflect.acronym 'RESTful'
# end

ActiveSupport::Inflector.inflections(:en) do |inflect|
  # Rails thinks all words ending in "men" are already plural
  inflect.irregular("specimen", "specimens")
  # The following acronym inflections will make Zeitwerk's life easier if
  # we consistently use them whenever they apear separately in snake case
  # eg, apizza_buona ApizzaBuona is ok, but api_concern ApiConcern is not
  inflect.acronym("API")
  inflect.acronym("API2")
  inflect.acronym("GM")
  inflect.acronym("HTTP")
  inflect.acronym("URL")
end
