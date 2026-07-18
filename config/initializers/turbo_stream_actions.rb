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

  # Like `prepend`, but the client skips the insert if an element with
  # the new content's id is already in the DOM. Lets a controller's
  # synchronous response and a model's async broadcast both try to
  # insert the same new record without risking a duplicate -- whichever
  # arrives first wins, the second is a no-op. See CommentsController.
  def prepend_once(target, content = nil, **rendering, &block)
    action(:prepend_once, target, content, **rendering, &block)
  end

  ::Turbo::Streams::TagBuilder.include(self)
end
