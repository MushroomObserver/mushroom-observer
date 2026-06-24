# frozen_string_literal: true

module Views::Controllers::SpeciesLists::NameLists
  # Submit form for the JavaScript name-lister UI. The list of
  # entered names is collected by the surrounding JS and embedded as
  # a single newline-separated string in the `:results` hidden field.
  # The user picks an output format via one of four submit buttons;
  # `params[:commit]` is dispatched by the controller.
  class Form < ::Components::ApplicationForm
    def initialize(name_strings:, user:, **)
      @name_strings = name_strings
      @user = user
      super(FormObject::NameLister.new(results: name_strings.join("\n")),
            id: "name_lister_form")
    end

    def view_template
      super do
        div(class: "text-center my-5") do
          submit(:name_lister_submit_spl.l, class: "mx-3", disabled: !@user)
          submit(:name_lister_submit_txt.l, class: "mx-3")
          submit(:name_lister_submit_rtf.l, class: "mx-3")
          submit(:name_lister_submit_csv.l, class: "mx-3")
        end
        hidden_field(:results)
        render(::Components::Help::Note.new(:div, :name_lister_help.tp))
      end
    end

    private

    def form_action
      url_for(controller: "/species_lists/name_lists",
              action: :create, only_path: true)
    end
  end
end
