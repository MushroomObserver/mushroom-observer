# frozen_string_literal: true

class InternalLink
  def initialize(title, url, html_options: {}, alt_title: nil)
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
             else
               @title
             end.parameterize(separator: "_")
    return result + "_link"
  end
end
