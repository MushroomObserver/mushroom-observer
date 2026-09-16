# frozen_string_literal: true

# Backs the sidebar's POST-based language switcher (issue #5074). The
# actual locale resolution already happens in
# ApplicationController::Internationalization#set_locale's before_action,
# which reads params[:user_locale] -- this action only needs to return
# the visitor to wherever they were.
class LocalesController < ApplicationController
  def update
    redirect_back_or_to(root_path)
  end
end
