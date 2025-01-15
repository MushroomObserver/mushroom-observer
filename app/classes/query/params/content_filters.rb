# frozen_string_literal: true

module Query::Params::ContentFilters
  # :with_images, :with_specimens, :lichen, :region, :clade
  def content_filter_parameter_declarations(model)
    ContentFilter.by_model(model).each_with_object({}) do |fltr, decs|
      decs[:"#{fltr.sym}?"] = fltr.type
    end
  end
end
