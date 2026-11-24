# frozen_string_literal: true

class Components::Alert::Link < Components::Base
  prop :text, String
  prop :href, String
  # Catch-all for class:, data:, aria:, and any other HTML attrs on
  # the rendered link -- matches Accordion/Icon/Collapsible's pattern.
  prop :attributes, _Hash(Symbol, _Any?), :**

  def view_template
    Link(type: :get, name: @text, target: @href,
         **mix({ class: "alert-link" }, @attributes))
  end
end
