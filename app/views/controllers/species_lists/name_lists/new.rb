# frozen_string_literal: true

# Phlex view for the name-lister page. The bulk of
# the UX is JavaScript (Stimulus `name-list` controller); this view
# wires the table chrome the JS hooks into, then renders the submit
# form for the resulting newline-separated name list.
#
# The `<table>` is itself a Stimulus root (table-level
# `data-controller="name-list"` + several `data-action` keypress /
# click handlers) and the body is two rows of different shape
# (a 3-column scrollers row + a `colspan="3"` submit-form row), so
# this uses `Components::Table` in body mode (caller renders the
# whole tbody) with table-level Stimulus attrs passed via
# `attributes:`.
module Views::Controllers::SpeciesLists::NameLists
  class New < Views::FullPageBase
    def initialize(name_strings:, user:)
      super()
      @name_strings = name_strings
      @user = user
    end

    def view_template
      add_page_title(:name_lister_title.t)
      add_context_nav(::Tab::SpeciesList::FormNameList.new)
      container_class(:full)
      render_noscript
      render_lister_table
    end

    private

    def render_noscript
      noscript do
        Container(width: :text, class: "mt-3") do
          trusted_html(:name_lister_no_js.tp)
        end
      end
    end

    # The whole `<table data-controller="name-list">` is the
    # Stimulus root the JS uses for keyboard navigation between the
    # three scroller columns + the submit form below.
    def render_lister_table
      render(Components::Table.new(
               class: "name-lister mt-3 w-100",
               attributes: { cols: "3", data: lister_data }
             )) do |t|
        t.column(:name_lister_genera.t, width: "20%")
        t.column(:name_lister_species.t, width: "40%")
        t.column(:name_lister_names.t, width: "40%")
        t.body { render_lister_body }
      end
    end

    def lister_data
      { controller: "name-list",
        action: "keypress->name-list#ourKeypress " \
                "keydown->name-list#ourKeydown " \
                "keyup->name-list#ourKeyup " \
                "click->name-list#ourUnfocus" }
    end

    def render_lister_body
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

    def scroller(target)
      div(id: target, class: "scroller",
          data: {
            name_list_target: target,
            action: "click->name-list#ourFocus"
          })
    end
  end
end
