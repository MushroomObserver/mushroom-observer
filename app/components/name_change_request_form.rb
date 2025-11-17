# frozen_string_literal: true

# Form for submitting a name change request email to admins.
# Allows users to request changing a taxonomic name.
class Components::NameChangeRequestForm < Components::ApplicationForm
  prop :name
  prop :new_name
  prop :new_name_with_icn_id

  def view_template
    super do
      p { :email_name_change_request_help.tp }

      field(:name).static(
        wrapper_options: {
          label: "#{:NAME.t}:",
          value: "#{@name.unique_search_name}[##{@name.icn_id}]",
          inline: true
        }
      )

      field(:new_name_with_icn_id).hidden(
        wrapper_options: {
          label: "#{:new_name.t}:",
          value: @new_name_with_icn_id,
          inline: true
        }
      )

      field(:notes).textarea(
        wrapper_options: {
          label: "#{:Notes.t}:"
        },
        rows: 10,
        value: "",
        data: { autofocus: true }
      )

      submit(:SEND.l, center: true)
    end
  end

  private

  def form_action
    {
      action: :create,
      name_id: @name.id,
      new_name: @new_name
    }
  end
end
