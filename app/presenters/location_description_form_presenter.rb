# frozen_string_literal: true

# Gather data for location description form.
class LocationDescriptionFormPresenter < BasePresenter
  attr_accessor \
    :method, # form_with method
    :button, # submit button text
    :url # form_with url

  def initialize(description, view, action)
    super

    case action
    when :create
      self.method = :post
      self.button = :CREATE.l
      self.url = { controller: "/locations/descriptions", action: :create,
                   id: description.location_id }
    when :update
      self.method = :put
      self.button = :UPDATE.l
      self.url = { controller: "/locations/descriptions", action: :update,
                   id: description.id, q: h.get_query_param }
    end
  end
end
