# frozen_string_literal: true

# Form for submitting a name change request email to admins.
# Allows users to request changing a taxonomic name.
class Components::NameChangeRequestForm < Components::ApplicationForm
  def initialize(model, name:, new_name_with_icn_id:, **)
    @name = name
    @new_name_with_icn_id = new_name_with_icn_id
    super(model, **)
  end

  def view_template
    super do
      p { :email_name_change_request_help.tp }
      render_name_field
      render_new_name_field
      render_notes_field
      submit(:SEND.l, center: true)
    end
  end

  private

  def render_name_field
    render(field(:name).static(
             wrapper_options: {
               label: "#{:NAME.t}:",
               value: "#{@name.unique_search_name}[##{@name.icn_id}]",
               inline: true
             }
           ))
  end

  def render_new_name_field
    render(field(:new_name_with_icn_id).read_only(
             wrapper_options: {
               label: "#{:new_name.t}:",
               value: @new_name_with_icn_id,
               inline: true
             }
           ))
  end

  def render_notes_field
    render(field(:notes).textarea(
             wrapper_options: {
               label: "#{:Notes.t}:"
             },
             rows: 10,
             value: "",
             data: { autofocus: true }
           ))
  end

  def form_action
    url_for(
      action: :create,
      name_id: @name.id,
      new_name_with_icn_id: @new_name_with_icn_id
    )
  end
end
