# frozen_string_literal: true

module ExportsHelper
  # Create button? to export an Image.
  def image_exporter(image_id, exported)
    link = export_link(image_id, exported)
    tag.div(link, id: "image_export_#{image_id}")
  end

  # TODO: Fix the javascript.
  def export_link(image_id, exported)
    if exported
      put_button(name: "Don't export",
                 path: export_image_path(id: image_id, value: 0))
    else
      put_button(name: "Export",
                 path: export_image_path(id: image_id, value: 1))
    end
  end

  def set_ml_status_controls(obj)
    status_controls(obj, obj.diagnostic,
                    :review_diagnostic.t, :review_non_diagnostic.t,
                    :set_ml_status)
  end

  # Display the two export statuses, making the current state plain text and
  # the other a link to the observer/set_export_status callback.
  def set_export_status_controls(obj)
    status_controls(obj, obj.ok_for_export,
                    :review_ok_for_export.t, :review_no_export.t,
                    :set_export_status)
  end

  def status_controls(obj, status, ok_msg, not_ok_msg, action)
    return unless reviewer?

    if status
      content_tag(:b, ok_msg, class: "text-nowrap")
    else
      link_with_query(ok_msg,
                      { controller: "/export",
                        action: action,
                        type: obj.type_tag,
                        id: obj.id, value: 1 },
                      class: "text-nowrap")
    end + " | " +
      if status
        link_with_query(not_ok_msg,
                        { controller: "/export",
                          action: action,
                          type: obj.type_tag,
                          id: obj.id, value: 0 },
                        class: "text-nowrap")
      else
        content_tag(:b, not_ok_msg)
      end
  end
end
