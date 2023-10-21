# frozen_string_literal: true

# see ajax_controller.rb
module AjaxController::APIKey
  # Activate mode: sets verified field of given APIKey, returns nothing.
  # Edit mode: sets notes field of given APIKey, returns new value.
  # In both cases returns error message if there is an error.
  # type::  "activate" or "edit"
  # id::    ID of APIKey
  # value:: New value of the notes field (edit mode only)
  def api_key
    @user = session_user!
    key   = APIKey.find(@id)
    raise("Permission denied") if key.user != @user

    case @type
    when "activate"
      activate_api_key(key)
    when "edit"
      edit_api_key(key, @value)
    end
  end

  private

  def activate_api_key(key)
    key.verify!
    render(plain: "")
  end

  def edit_api_key(key, value)
    raise(:runtime_api_key_notes_cannot_be_blank.l) if value.blank?

    key.update_attribute(:notes, value.strip_squeeze)
    render(plain: key.notes)
  end
end
