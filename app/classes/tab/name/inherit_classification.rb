# frozen_string_literal: true

# "Inherit classification" link on the classification panel — goes
# to the inherit-classification form so the user can pick which
# ancestor Name's classification to pull down.
#
# Visibility predicate: rendered only when this Name is
# at-or-above Genus AND has no classification of its own. Use
# `.for(name:)` to get a Tab instance OR nil — the view checks the
# nil case and skips rendering.
class Tab::Name::InheritClassification < Tab::Base
  def self.for(name:)
    return nil unless visible_for?(name: name)

    new(name: name)
  end

  def self.visible_for?(name:)
    !name.below_genus? && name.classification.blank?
  end

  def initialize(name:)
    super()
    @name = name
  end

  def title
    :show_name_inherit_classification.t
  end

  def alt_title
    "inherit_classification"
  end

  def path
    form_to_inherit_classification_of_name_path(@name.id)
  end
end
