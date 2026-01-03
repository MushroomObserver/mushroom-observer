# frozen_string_literal: true

module Components
  module Sidebar
    # Base class for sidebar sections that render a heading and list of links
    #
    # Subclasses must implement:
    # - heading_key: returns the translation key for the section heading
    # - tabs_method: returns the method name to call for getting tabs
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

      # Subclasses must implement these methods
      def heading_key
        raise NotImplementedError, "#{self.class} must implement #heading_key"
      end

      def tabs_method
        raise NotImplementedError, "#{self.class} must implement #tabs_method"
      end
    end
  end
end
