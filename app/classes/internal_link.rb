# frozen_string_literal: true

class InternalLink
  attr_reader :url

  def initialize(title, url, html_options: {}, css_class: nil)
    @title = title
    @css_class = css_class
    @url = url
    @html_options = html_options
    @html_options[:class] = [@html_options[:class],
                             html_class].compact.join(" ")
  end

  def tab
    [@title, @url, @html_options]
  end

  private

  def html_class
    result = (@css_class || @title).parameterize(separator: "_")
    "#{result}_link"
  end
end
