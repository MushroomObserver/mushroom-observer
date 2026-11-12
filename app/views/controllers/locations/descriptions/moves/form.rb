# frozen_string_literal: true

module Views::Controllers::Locations::Descriptions::Moves
  # Form for moving a description to a different Location. Location has
  # no synonym concept, so unlike Names::Descriptions::Moves::Form (a
  # fixed radio list of synonyms), the destination is picked with a
  # Location autocompleter -- any Location is a valid target.
  class Form < ::Components::ApplicationForm
    prop :description, ::LocationDescription
    prop :user, ::User

    def initialize(description, user:, **)
      form_object = FormObject::DescriptionMoveOrMerge.new
      form_object.delete = description.is_admin?(user)
      # Keep the explicit DOM id — tests rely on it.
      super(form_object, description: description, user: user,
                         id: "move_descriptions_form", **)
    end

    def view_template
      h4 { append_colon(:merge_descriptions_move_location_header.t) }
      Help(element: :p,
           content: :merge_descriptions_move_location_help.t)

      div(class: "form-group") { render_location_field }
      render_delete_checkbox
      render_submit
    end

    private

    # field_name :target gives the autocompleter's hidden field the
    # default name target_id -- the param check_dest_exists! reads.
    # value/hidden_value stay nil; this form has no destination
    # pre-selected on load.
    def render_location_field
      autocompleter_field(:target, type: :location,
                                   label: :location.ti,
                                   value: nil,
                                   hidden_value: nil)
    end

    def render_delete_checkbox
      checkbox_field(:delete, label: :merge_descriptions_delete_after)
    end

    def render_submit
      submit(:submit.ti, center: true)
    end

    def form_action
      url_for(controller: "/locations/descriptions/moves", action: :create,
              id: @description.id, only_path: true)
    end

    def form_method
      :post
    end
  end
end
