# frozen_string_literal: true

# "Cancel and show this herbarium" link — used from forms (edit,
# curator request) to return to the herbarium's show page.
class Tab::Herbarium::Return < Tab::Base
  def initialize(herbarium:)
    super()
    @herbarium = herbarium
  end

  def title
    :cancel_and_show.t(type: :herbarium)
  end

  def path
    herbarium_path(@herbarium)
  end

  def model
    @herbarium
  end
end
