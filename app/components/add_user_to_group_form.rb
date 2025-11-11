# frozen_string_literal: true

# Form for adding a user to a group (admin only)
# Note: This form doesn't use Superform because it needs bare field names
# without a prefix (matches old form_with(url:) without model behavior)
class Components::AddUserToGroupForm < Phlex::HTML
  include Phlex::Rails::Helpers::FormAuthenticityToken
  include Phlex::Rails::Helpers::Routes

  def initialize(model, action:, id:)
    super()
    @model = model
    @action = action
    @form_id = id
  end

  def view_template
    form(action: @action, method: "post", id: @form_id) do
      input(name: "authenticity_token", type: "hidden",
            value: form_authenticity_token)

      render_user_name_field
      render_group_name_field
      render_submit_button
    end
  end

  private

  def render_user_name_field
    div(class: "form-group") do
      div(class: "d-flex justify-content-between") do
        div do
          label(for: "user_name", class: "mr-3") do
            "#{:add_user_to_group_user.t}:"
          end
        end
      end
      input(
        id: "user_name",
        name: "user_name",
        type: "text",
        value: @model.user_name,
        data: { autofocus: true },
        class: "form-control"
      )
    end
  end

  def render_group_name_field
    div(class: "form-group") do
      div(class: "d-flex justify-content-between") do
        div do
          label(for: "group_name", class: "mr-3") do
            "#{:add_user_to_group_group.t}:"
          end
        end
      end
      input(
        id: "group_name",
        name: "group_name",
        type: "text",
        value: @model.group_name,
        class: "form-control"
      )
    end
  end

  def render_submit_button
    input(
      type: "submit",
      value: :ADD.t,
      class: "btn btn-default center-block my-3",
      data: {
        turbo_submits_with: :SUBMITTING.l,
        disable_with: :ADD.t
      }
    )
  end
end
