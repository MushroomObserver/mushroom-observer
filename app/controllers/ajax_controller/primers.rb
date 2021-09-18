# frozen_string_literal: true

# see ajax_controller.rb
class AjaxController
  # Get list of names for autocompletion in mobile app.
  def name_primer
    render(json: name_list)
  end

  # Get list of locations for autocompletion in mobile app.
  def location_primer
    render(json: location_list)
  end

  private

  def name_list
    name_ids = Observation.select(:name_id).distinct
    fields = [:id, :text_name, :author, :deprecated, :synonym_id]
    names = Name.where(id: name_ids).select(*fields)
    synonyms = names.to_a.map(&:synonym_id).reject(&:nil?).uniq
    names | Name.where(deprecated: false, synonym_id: synonyms).select(*fields)
  end

  def location_list
    Observation.where.not(location: nil).
      select(:location_id, :where).distinct.map do |obs|
      { id: obs.location_id, name: obs.where }
    end
  end
end
