module ExporterHelper
  # Create button? to export an Image.
  def image_exporter(image_id, exported)
    link = export_link(image_id, exported)
    content_tag(:div, link, id: "image_export_#{image_id}")
  end

  # TODO: Fix the javascript.
  def export_link(image_id, exported)
    if exported
      link_to("", {}, onclick: "image_export(#{image_id},0)")
    else
      link_to("", {}, onclick: "image_export(#{image_id},1)")
    end
  end

  # Display the two export statuses, making the current state plain text and
  # the other a link to the observations/set_export_status callback.
  def set_export_status_controls(obj)
    if reviewer?
      if obj.ok_for_export
        content_tag(:b, :review_ok_for_export.t, class: "text-nowrap")
      else
        link_with_query(:review_ok_for_export.t,
                        { controller: :observations,
                          action: :set_export_status,
                          type: obj.type_tag,
                          id: obj.id, value: 1 },
                        class: "text-nowrap")
      end + " | " +
        if obj.ok_for_export
          link_with_query(:review_no_export.t,
                          { controller: :observations,
                            action: :set_export_status,
                            type: obj.type_tag,
                            id: obj.id, value: 0 },
                          class: "text-nowrap")
        else
          content_tag(:b, :review_no_export.t)
        end
    end
  end
end
