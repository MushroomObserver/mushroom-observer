# frozen_string_literal: true

# Herbarium-records sub-panel — same shape as
# `CollectionNumbersPanel` but for `HerbariumRecord`s, with an
# additional "search MCP" indented link for records whose
# herbarium is `web_searchable?`
class Views::Controllers::Observations::Show::HerbariumRecordsPanel < Views::Base
  prop :obs, ::Observation
  prop :user, _Nilable(::User), default: nil
  prop :has_sibling_records, _Boolean, default: false

  def view_template
    div(
      id: "observation_herbarium_records",
      class: "obs-herbarium",
      data: { controller: "section-update",
              section_update_user_value: @user&.id }
    ) do
      render_body
    end
  end

  private

  def render_body
    records = @obs.herbarium_records
    if records.any? && can_add?
      render_editable_list(records)
    elsif records.any?
      render_readonly_list(records)
    elsif can_add?
      render_empty_with_new_link
    end
  end

  # Editable when admin, obs owner, or any curated herbarium.
  def can_add?
    in_admin_mode? || @obs.can_edit?(@user) ||
      @user&.curated_herbaria&.any?
  end

  def render_editable_list(records)
    div do
      plain("#{:herbarium_records.ti}: ")
      render_new_link
    end
    ul(class: "tight-list") do
      records.each { |r| render_editable_row(r) }
    end
  end

  def render_editable_row(record)
    li(id: "herbarium_record_#{record.id}") do
      render_show_link(record)
      Link(type: :inline_mod,
           target: record, observation: @obs, user: @user)
      render_mcp_search_link(record) if record.herbarium.web_searchable?
    end
  end

  def render_show_link(record)
    content, path, opts = ::Tab::HerbariumRecord::Show.new(
      herbarium_record: record, observation: @obs
    ).to_a
    a(href: url_for(path), **opts) { trusted_html(content) }
  end

  def render_mcp_search_link(record)
    br
    span(class: "indent") do
      Link(type: :external,
           content: :herbarium_record_collection.t,
           path: record.herbarium.mcp_url(record.accession_number))
    end
  end

  # Read-only list: `div` heading + tight-list with show-link + br +
  # MCP search link when web-searchable).
  def render_readonly_list(records)
    div { plain("#{:herbarium_record.ti}:") }
    ul(class: "tight-list") do
      records.each { |record| render_readonly_row(record) }
    end
  end

  def render_readonly_row(record)
    li(id: "herbarium_record_#{record.id}") do
      render_show_link(record)
      if record.herbarium.web_searchable?
        br
        Link(type: :external,
             content: "#{record.herbarium.code} " \
                      "#{:herbarium_record_collection.t}",
             path: record.herbarium.mcp_url(record.accession_number))
      end
    end
  end

  def render_empty_with_new_link
    label = if @has_sibling_records
              "#{:herbarium_records.ti}: "
            else
              "#{:show_observation_no_herbarium_records.t} "
            end
    plain(label)
    render_new_link
  end

  def render_new_link
    Link(type: :inline_add,
         modal_id: "herbarium_record",
         tab: ::Tab::HerbariumRecord::New.new(observation: @obs))
  end
end
