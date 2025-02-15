# frozen_string_literal: true

module Query::Params::Filters
  def self.included(base)
    base.extend(ClassMethods)
  end

  module ClassMethods
    # Currently, these are
    # :with_images, :with_specimens, :lichen, :region, :clade
    def content_filter_parameter_declarations(model)
      Query::Filter.by_model(model).each_with_object({}) do |fltr, decs|
        decs[fltr.sym] = fltr.type
      end
    end
  end
end
