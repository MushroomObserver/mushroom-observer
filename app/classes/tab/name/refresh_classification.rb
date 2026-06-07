# frozen_string_literal: true

# "Refresh classification" PUT button on the classification panel —
# pushes the accepted Genus's stored classification down onto this
# Name when the two diverge.
#
# Visibility predicate: rendered only when the Name is below Genus
# AND its `classification` text differs (whitespace-stripped) from
# its accepted Genus's. Use `.for(name:)` to get a Tab instance OR
# nil — the view checks the nil case and skips rendering.
class Tab::Name::RefreshClassification < Tab::Base
  def self.for(name:)
    return nil unless visible_for?(name: name)

    new(name: name)
  end

  def self.visible_for?(name:)
    name.below_genus? &&
      name.accepted_genus.try(&:classification).to_s.strip !=
        name.classification.to_s.strip
  end

  def initialize(name:)
    super()
    @name = name
  end

  def title
    :show_name_refresh_classification.t
  end

  def alt_title
    "refresh_classification"
  end

  def path
    refresh_classification_of_name_path(@name.id)
  end

  # `button: :put` tells `Components::CrudButton::Put` (or any
  # tab-rendering consumer) to emit a `<button>` posting PUT,
  # matching the legacy `put_button(...)` helper output.
  def html_options
    { button: :put }
  end
end
