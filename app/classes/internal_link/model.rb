# frozen_string_literal: true

module InternalLink
  class Model
    def initialize(title, model, url, html_options: {}, alt_title: nil)
      @model = model
      @title = title
      @alt_title = alt_title
      @url = url
      @html_options = html_options
      @html_options[:class] = html_class unless @html_options.include?(:class)
    end

    def tab
      [@title, @url, @html_options]
    end

    private

    def html_class
      result = if @alt_title
                 @alt_title
               elsif @title.include?(model_name)
                 @title
               else
                 "#{@title}_#{model_name}"
               end.parameterize(separator: "_")
      result += "_link"
      return result unless @model.respond_to?(:id)

      "#{result}_#{@model.id}"
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
