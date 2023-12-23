# frozen_string_literal: true

# https://stackoverflow.com/questions/77421369/turbo-response-to-render-javascript-alert/77434363#77434363
# this is optional but makes it much cleaner
module CustomTurboStreamActions
  def close_modal(id)
    action(:close_modal, "#", id)
  end

  ::Turbo::Streams::TagBuilder.include(self)
end
