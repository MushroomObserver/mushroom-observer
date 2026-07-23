# frozen_string_literal: true

# A single row in the Names index list.
#
# Each row carries:
#   - `Components::IDBadge` with the Name's id
#   - the localized display-name link (with a Stimulus
#     `clipboard` controller wrapped around the name + a
#     copy-button so users can clipboard the name string)
#   - the observations count badge (per-name count derived in
#     bulk by the Index view via `Name.count_observations`)
#   - on the `has_descriptions` subaction only, three extra
#     `<span>`s with the description's authors / note status /
#     review status
class Views::Controllers::Names::Index::Row < Views::Base
  prop :name, ::Name
  prop :user, _Nilable(::User), default: nil
  prop :counts, _Hash(Integer, Integer), default: -> { {} }
  prop :has_descriptions, _Boolean, default: false

  # Row contents only — the surrounding `<div class="list-group-item">`
  # is emitted by `Components::ListGroup` in the Index view.
  def view_template
    render_id_badge
    render_clipboard_wrapper
    render_count_badge
    render_description_columns if @has_descriptions
  end

  private

  def render_id_badge
    span do
      IDBadge(object: @name, size: :md)
    end
  end

  def render_clipboard_wrapper
    span(
      data: { controller: "clipboard",
              clipboard_copied_value: :copied.ti }
    ) do
      render_display_name_link
      render_copy_button
    end
  end

  def render_display_name_link
    a(href: name_path(@name.id)) do
      span(class: "display-name",
           data: { clipboard_target: "source" }) do
        trusted_html(@name.display_name(@user).t)
      end
    end
  end

  def render_copy_button
    Button(
      variant: :link,
      class: "py-0 link-normal opacity-75",
      role: "button",
      data: { tooltip_target: "tip", placement: "bottom",
              title: :copy_this_name.ti,
              action: "clipboard#copy" }
    ) { Icon(type: :copy) }
  end

  def render_count_badge
    count = @counts[@name.id]
    return unless count

    span(class: "badge") { plain(count.to_s) }
  end

  # `has_descriptions` subaction columns: when a description
  # exists, show authors / note status / review status; when it
  # doesn't, show the placeholder text.
  def render_description_columns
    desc = @name.description
    return span { plain("--- not the default ---") } unless desc

    span { plain(desc.authors.map(&:login).join(", ")) }
    span { plain(desc.note_status.join("/")) }
    span { plain(:"review_#{desc.review_status}".l) }
  end
end
