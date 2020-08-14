# frozen_string_literal: true

# see ajax_controller.rb
class AjaxController
  # Activate mode: sets verified field of given ApiKey, returns nothing.
  # Edit mode: sets notes field of given ApiKey, returns new value.
  # In both cases returns error message if there is an error.
  # type::  "activate" or "edit"
  # id::    ID of ApiKey
  # value:: New value of the notes field (edit mode only)
  def api_key
    @user = session_user!
    key   = ApiKey.find(@id)
    raise("Permission denied") if key.user != @user

    if @type == "activate"
      activate_api_key(key)
    elsif @type == "edit"
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
