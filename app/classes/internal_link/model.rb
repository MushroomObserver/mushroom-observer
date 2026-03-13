# frozen_string_literal: true

class InternalLink
  class Model < InternalLink
    def initialize(title, model, url, html_options: {}, alt_title: nil)
      @model = model
      super(title, url, html_options:, alt_title:)
    end

    private

    def html_class
      result = if @alt_title
                 @alt_title
               elsif @title.underscore.tr(" ", "_").include?(model_name)
                 @title
               else
                 "#{@title}_#{model_name}"
               end.parameterize(separator: "_")
      result += "_link"
      return result unless @model.respond_to?(:id)

      "#{result} #{result}_#{@model.id}"
    end

    def model_name
      @model_name ||= if @model.is_a?(Class)
                        @model
                      else
                        @model.class
                      end.name.underscore
    end
  end
end
