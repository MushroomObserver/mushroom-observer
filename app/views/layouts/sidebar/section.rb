# frozen_string_literal: true

class Views::Layouts::Sidebar
  # Base class for sidebar sections that render a heading and list of
  # links.
  #
  # Can be used directly by passing heading_key and tabs as props, or
  # subclassed for more complex rendering (e.g., Login and Admin).
  #
  # @example Direct usage
  #   render(Views::Layouts::Sidebar::Section.new(
  #     heading_key: :indexes,
  #     tabs: Tab::Sidebar::IndexesActions.new.map(&:to_a),
  #     classes: Views::Layouts::Sidebar::CSS_CLASSES
  #   ))
  class Section < ::Components::Base
    prop :user, _Nilable(::User), default: nil
    prop :classes, _Hash(Symbol, String)
    prop :heading_key, _Nilable(Symbol), default: nil
    prop :tabs, _Nilable(_Array(_Nilable(Array))), default: nil

    def view_template
      render(Components::ListGroup::Item.new(class: @classes[:heading])) do
        plain("#{@heading_key.ti}:")
      end

      @tabs.compact.each do |link|
        render_nav_link(link)
      end
    end

    private

    def render_nav_link(link, link_class: @classes[:indent])
      title, url, html_options = link
      html_options ||= {}
      extra_class = html_options.delete(:class)

      render(
        Components::ListGroup::LinkItem.new(class: link_class)
      ) do |css_class|
        Link(type: :active, content: title, path: url,
             class: class_names(css_class, extra_class), **html_options)
      end
    end
  end
end
