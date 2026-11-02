# frozen_string_literal: true

# Form object for Names::ClassificationController's edit form. One
# plain-text attribute per rank above Genus, in descending taxonomic
# order (Domain first). Field names match the rank_* translation
# tags (`:rank_domain`, `:rank_class`, etc.) -- "class" alone would
# shadow Object#class, so every rank is prefixed rank_.
class FormObject::NameClassification < FormObject::Base
  RANKS = ::Name.ranks_above_genus.reverse.freeze

  RANKS.each { |rank| attribute(:"rank_#{rank.downcase}", :string) }

  # Superform picks PUT/PATCH vs. POST from this -- the form edits an
  # existing Name's classification, not a new record.
  def persisted?
    true
  end
end
