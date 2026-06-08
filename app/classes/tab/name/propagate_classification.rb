# frozen_string_literal: true

# "Propagate classification" PUT button on the classification panel
# — pushes this Name's classification down onto its subtaxa.
#
# Visibility predicate: rendered only when this Name can propagate
# (has subtaxa AND is at-or-above-genus) AND has a non-blank
# classification to propagate. Use `.for(name:)` to get a Tab
# instance OR nil — the view checks the nil case and skips
# rendering.
class Tab::Name::PropagateClassification < Tab::Base
  def self.for(name:)
    return nil unless visible_for?(name: name)

    new(name: name)
  end

  def self.visible_for?(name:)
    name.can_propagate? && name.classification.present?
  end

  def initialize(name:)
    super()
    @name = name
  end

  def title
    :show_name_propagate_classification.t
  end

  def alt_title
    "propagate_classification"
  end

  def path
    propagate_classification_of_name_path(@name.id)
  end

  def html_options
    { button: :put }
  end
end
