# see ajax_controller.rb
class AjaxController
  # Return an old TranslationString by version id.
  def old_translation
    str = TranslationString::Version.find(@id)
    render(plain: str.text)
  end
end
