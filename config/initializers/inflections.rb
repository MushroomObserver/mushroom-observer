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
  # "taxon" is a core MO concept; Rails' default inflector doesn't know
  # the Greek "-on" -> "-a" plural (unlike "criterion"/"phenomenon").
  inflect.irregular("taxon", "taxa")
  inflect.acronym("API")
  inflect.acronym("API2")
  inflect.acronym("GM")
  inflect.acronym("HTTP")
  inflect.acronym("URL")
  inflect.acronym("EXIF")
  inflect.acronym("CSV")
  inflect.acronym("TSV")
  inflect.acronym("QR")
  inflect.acronym("UI")
  inflect.acronym("CRUD")
  inflect.acronym("ID")
  inflect.acronym("OK")
  # International Code of Nomenclature -- MO's own taxonomic domain
  # acronym, not tied to any specific Rails call site.
  inflect.acronym("ICN")
  inflect.irregular("bonus", "bonuses")
  inflect.irregular("info", "info")
  inflect.irregular("google", "google")
  inflect.irregular("search", "search")
  inflect.irregular("user_stats", "user_stats")
  inflect.irregular("search", "search")
end
