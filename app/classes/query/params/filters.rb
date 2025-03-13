# frozen_string_literal: true

module Query::Params::Filters
  def self.included(base)
    base.extend(ClassMethods)
  end

  module ClassMethods
    # Get all param keys with `Query::Filter.all.map(&:sym)`.
    # Current params [:has_images, :has_specimens, :lichen, :regions, :clades]
    def content_filter_parameter_declarations(model)
      Query::Filter.by_model(model).each_with_object({}) do |fltr, decs|
        decs[fltr.sym] = fltr.type
      end.merge(preference_filter: { boolean: [true] })
    end
  end
end
