# frozen_string_literal: true

# "Edit herbarium record" link. `back` controls the redirect target
# after editing — `obs.id` to return to a specific observation,
# `:index` to return to the herbarium_records index (pass
# `from_index: true`), `:show` to return to the herbarium_record
# show page (the default when neither is given).
class Tab::HerbariumRecord::Edit < Tab::Base
  def initialize(herbarium_record:, observation: nil, from_index: false)
    super()
    @herbarium_record = herbarium_record
    @observation = observation
    @from_index = from_index
  end

  def title
    :edit_herbarium_record.l
  end

  def path
    edit_herbarium_record_path(@herbarium_record.id, back: back)
  end

  def html_options
    { icon: :edit }
  end

  def model
    @herbarium_record
  end

  private

  def back
    return @observation.id if @observation
    return :index if @from_index

    :show
  end
end
