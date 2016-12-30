# encoding: utf-8
class AjaxController
  # Return an old TranslationString by version id.
  def old_translation
    str = TranslationString::Version.find(@id)
    render(text: str.text)
  end
end
