# frozen_string_literal: true

# Collection-numbers sub-panel on the observation details panel.
# When the user can edit the obs:
#   - Header line "Collection numbers: [ new ]"
#   - Bulleted list, each row: link to show + `[ edit | remove ]`
# When the user can't edit and there are records: a one-line
# "Collection number(s): link, link"
# When there are no records but the user can edit: "no records [ new ]"
#
# `remove_collection_number_button` is handled by
# `Components::Link::InlineMod` which knows how to detach a
# `CollectionNumber` from its observation.
class Views::Controllers::Observations::Show::CollectionNumbersPanel < Views::Base
  prop :obs, ::Observation
  prop :user, _Nilable(::User), default: nil
  prop :has_sibling_records, _Boolean, default: false

  def view_template
    div(
      id: "observation_collection_numbers",
      class: "obs-collection",
      data: { controller: "section-update",
              section_update_user_value: @user&.id }
    ) do
      render_body
    end
  end

  private

  def render_body
    numbers = @obs.collection_numbers
    if numbers.any? && can_edit?
      render_editable_list(numbers)
    elsif numbers.any?
      render_readonly_list(numbers)
    elsif can_edit?
      render_empty_with_new_link
    end
  end

  def can_edit?
    in_admin_mode? || @obs.can_edit?(@user)
  end

  # Editable list: header + tight-list with edit/remove links.
  def render_editable_list(numbers)
    div do
      plain("#{:collection_numbers.ti}: ")
      render_new_link
    end
    ul(class: "tight-list") do
      numbers.each { |n| render_editable_row(n) }
    end
  end

  def render_editable_row(number)
    li(id: "collection_number_#{number.id}") do
      render_show_link(number)
      Link(type: :inline_mod,
           target: number, observation: @obs, user: @user)
    end
  end

  def render_show_link(number)
    content, path, opts = ::Tab::CollectionNumber::Show.new(
      collection_number: number, observation: @obs
    ).to_a
    a(href: url_for(path), **opts) { trusted_html(content) }
  end

  # Read-only one-liner: "Collection number(s): a, b, c"
  def render_readonly_list(numbers)
    label = numbers.length > 1 ? :Collection_numbers : :Collection_number
    plain("#{label.t}: ")
    numbers.each_with_index do |number, idx|
      plain(", ") if idx.positive?
      render_show_link(number)
    end
  end

  # No records yet but user can add: status text + `[+]`.
  def render_empty_with_new_link
    label = if @has_sibling_records
              "#{:collection_numbers.ti}: "
            else
              "#{:show_observation_no_collection_numbers.t} "
            end
    plain(label)
    render_new_link
  end

  def render_new_link
    Link(type: :inline_add,
         modal_id: "collection_number",
         tab: ::Tab::CollectionNumber::New.new(observation: @obs))
  end
end
