# frozen_string_literal: true

module Translations
  class VersionsController < ApplicationController
    before_action :login_required

    # Show past versions of Translation.
    # Accessible only from translations/index page js.
    def show
      str = TranslationString::Version.find(@id)

      @versions = str.text
      # render(plain: str.text)
      # should render js
    end
  end
end
