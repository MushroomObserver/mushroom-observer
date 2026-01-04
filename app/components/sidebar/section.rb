# frozen_string_literal: true

module Components
  module Sidebar
    # Base class for sidebar sections that render a heading and list of links
    #
    # Can be used directly by passing heading_key and tabs as props, or
    # subclassed for more complex rendering (e.g., Login and Admin components).
    #
    # @example Direct usage
    #   render(Components::Sidebar::Section.new(
    #     heading_key: :INDEXES,
    #     tabs: sidebar_indexes_tabs,
    #     classes: sidebar_css_classes
    #   ))
    #
    class Section < Components::Base
      prop :user, _Nilable(::User), default: nil
      prop :classes, _Hash(Symbol, String)
      prop :heading_key, _Nilable(Symbol), default: nil
      prop :tabs, _Nilable(_Array(_Nilable(Array))), default: nil

      register_output_helper :active_link_to

      def view_template
        div(class: @classes[:heading]) do
          plain("#{@heading_key.t}:")
        end

        tabs_array.compact.each do |link|
          render_nav_link(link)
        end
      end

      private

      def tabs_array
        @tabs || tabs
      end

      def tabs
        if method(tabs_method).arity.zero?
          send(tabs_method)
        else
          send(tabs_method, @user)
        end
      end

      def render_nav_link(link, link_class: @classes[:indent])
        title, url, html_options = link
        html_options ||= {}
        html_options[:class] = class_names(
          link_class,
          html_options[:class]
        )

        active_link_to(title, url, **html_options)
      end
    end
  end
end
