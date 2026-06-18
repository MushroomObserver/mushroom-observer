# frozen_string_literal: true

# Action template for `FieldSlipsController#show` — the single
# field-slip page. Sets page chrome (title + edit icons), renders
# any flash notice as an Alert, then the `FieldSlipPanel` inside the
# padded content wrapper, then the standard `Views::Layouts::ObjectFooter`.
#
# Replaces `app/views/controllers/field_slips/show.html.erb`.
module Views::Controllers::FieldSlips
  class Show < Views::FullPageBase
    prop :field_slip, ::FieldSlip
    prop :notice, _Nilable(String), default: nil

    def view_template
      add_page_title("#{:FIELD_SLIP.t}: #{@field_slip.code}")
      add_edit_icons(@field_slip, current_user)
      container_class(:full)

      if @notice
        render(Components::Alert.new(message: @notice, level: :success))
      end

      # Match the wrapper that the ERB-era `content_padded` helper
      # emitted (`<div class="p-3">`). Registering the helper on
      # `Views::Base` isn't worth it for one caller in the codebase.
      div(class: "p-3") do
        render(FieldSlipPanel.new(field_slip: @field_slip))
      end

      render(Views::Layouts::ObjectFooter.new(
               user: current_user, obj: @field_slip
             ))
    end
  end
end
