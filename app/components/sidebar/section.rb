# frozen_string_literal: true

module Components
  module Sidebar
    # Base class for sidebar sections that render a heading and list of links
    #
    # The default view_template expects subclasses to implement:
    # - heading_key: returns the translation key for the section heading
    # - tabs_method: returns the method name to call for getting tabs
    #
    # Subclasses may override view_template entirely if they need custom
    # rendering (e.g., Login and Admin components).
    #
    class Section < Components::Base
      prop :user, _Nilable(::User), default: nil
      prop :classes, _Hash(Symbol, String)

      register_output_helper :active_link_to

      def view_template
        div(class: @classes[:heading]) do
          plain("#{heading_key.t}:")
        end

        tabs.compact.each do |link|
          render_nav_link(link)
        end
      end

      private

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

      # NOTE: Subclasses using the default view_template should implement:
      # - heading_key: returns a translation key symbol (e.g., :app_more)
      # - tabs_method: returns a method name symbol (e.g., :sidebar_info_tabs)
      #
      # If these methods are missing, Ruby will raise NoMethodError when
      # view_template is called.
    end
  end
end
