# frozen_string_literal: true

# see ajax_controller.rb
module AjaxController::OldTranslation
  # Return an old TranslationString by version id.
  def old_translation
    str = TranslationString::Version.find(@id)
    render(plain: str.text)
  end
end
