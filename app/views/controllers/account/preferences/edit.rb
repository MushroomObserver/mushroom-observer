# frozen_string_literal: true

# Action view for `account/preferences#edit`. Replaces
# `account/preferences/edit.html.erb` and its `_put_buttons` partial.
# The form itself is `Components::AccountPreferencesForm`.
module Views::Controllers::Account::Preferences
  class Edit < Views::Base
    prop :user, _Nilable(User)
    prop :licenses, Array, default: -> { [] }

    def view_template
      add_page_title(:prefs_title.t)
      add_context_nav(account_preferences_edit_tabs)

      render(Components::AccountPreferencesForm.new(@user, licenses: @licenses))
      render_put_buttons
    end

    private

    # PUT buttons sit outside the main form so a click on any of them
    # submits to the targeted action rather than `PATCH /preferences`.
    def render_put_buttons
      div(class: "form-group mt-3") do
        put_button_in_help_note(:prefs_change_image_vote_anonymity.t,
                                images_bulk_vote_anonymity_updater_path)
        put_button_in_help_note(:prefs_bulk_filename_purge.t,
                                images_bulk_filename_purge_path,
                                data: { confirm:
                                        :prefs_bulk_filename_purge_confirm.l })
        put_button_in_help_note(:bulk_license_link.t,
                                images_edit_licenses_path)
      end
    end

    def put_button_in_help_note(name, path, **)
      div(class: "help-note") do
        render(Components::CrudButton::Put.new(
                 name: name, target: path, class: "btn btn-link", **
               ))
      end
    end
  end
end
