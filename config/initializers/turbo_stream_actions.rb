# frozen_string_literal: true

# https://stackoverflow.com/a/77434363/3357635
# this is optional but makes it much cleaner
module CustomTurboStreamActions
  def close_modal(id)
    action(:close_modal, "#", id)
  end

  def update_input(id, value)
    action(:update_input, id, value)
  end

  def add_class(id, class_name)
    action(:add_class, id, class_name)
  end

  def remove_class(id, class_name)
    action(:remove_class, id, class_name)
  end

  ::Turbo::Streams::TagBuilder.include(self)
end
