# frozen_string_literal: true

# Phlex view for the name-lister page. Replaces new.erb. The bulk of
# the UX is JavaScript (Stimulus `name-list` controller); this view
# wires the table chrome the JS hooks into, then renders the submit
# form for the resulting newline-separated name list.
module Views::Controllers::SpeciesLists::NameLists
  class New < Views::Base
    register_value_helper :species_list_form_name_list_tabs

    def initialize(name_strings:, user:)
      super()
      @name_strings = name_strings
      @user = user
    end

    def view_template
      add_page_title(:name_lister_title.t)
      add_context_nav(species_list_form_name_list_tabs)
      container_class(:full)
      render_noscript
      render_lister_table
    end

    private

    def render_noscript
      noscript do
        div(class: "container-text mt-3") do
          trusted_html(:name_lister_no_js.tp)
        end
      end
    end

    # The whole `<table data-controller="name-list">` is the
    # Stimulus root the JS uses for keyboard navigation between the
    # three scroller columns + the submit form below.
    def render_lister_table
      table(cols: "3", class: "name-lister mt-3 w-100",
            data: {
              controller: "name-list",
              action: "keypress->name-list#ourKeypress " \
                      "keydown->name-list#ourKeydown " \
                      "keyup->name-list#ourKeyup " \
                      "click->name-list#ourUnfocus"
            }) do
        render_thead
        render_tbody
      end
    end

    def render_thead
      thead do
        tr do
          th(width: "20%") { :name_lister_genera.t }
          th(width: "40%") { :name_lister_species.t }
          th(width: "40%") { :name_lister_names.t }
        end
      end
    end

    def render_tbody
      tbody do
        tr do
          td { scroller("genera") }
          td { scroller("species") }
          td { scroller("names") }
        end
        tr do
          td(colspan: "3") do
            # Sibling reference within the namespace.
            render(Form.new(name_strings: @name_strings, user: @user))
          end
        end
      end
    end

    def scroller(target)
      div(id: target, class: "scroller",
          data: {
            name_list_target: target,
            action: "click->name-list#ourFocus"
          })
    end
  end
end
