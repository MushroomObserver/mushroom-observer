# frozen_string_literal: true

module Views::Controllers::SpeciesLists::WriteIn
  # Action view for the species_list write-in `new` page (also
  # re-rendered by the `create` action on validation failure).
  # Replaces `new.html.erb` — sets the page chrome and delegates
  # to the Phlex `Form`.
  class New < Views::FullPageBase
    def initialize(species_list:, user:, button:, **state)
      super()
      @species_list = species_list
      @user = user
      @button = button
      @state = state
    end

    def view_template
      add_page_title(
        :species_list_write_in_title.t(list_title: @species_list.title)
      )
      add_context_nav(::Tab::SpeciesList::FormWriteIn.new(list: @species_list))
      container_class(:text)

      render(Form.new(@species_list,
                      user: @user,
                      button: @button,
                      **@state))
    end
  end
end
