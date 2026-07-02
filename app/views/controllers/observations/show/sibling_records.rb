# frozen_string_literal: true

# Sibling-records concern for the observation details panel:
# extracted out of `ObservationDetailsPanel` to keep that class
# under the Phlex `Metrics/ClassLength` cop limit — the sibling
# rendering is a distinct concern (read-only aggregation across
# siblings in an occurrence) from the obs's own details.
#
# Mixed into `ObservationDetailsPanel`. The methods read
# `@siblings` directly; the host class owns the prop.
module Views::Controllers::Observations::Show::SiblingRecords
  # Read-only `<ul class="tight-list">` of records aggregated
  # from sibling observations. Caller's block yields
  # `(record, sibling)` per row. No-op when no siblings have
  # records for the requested association.
  #
  def render_sibling_records(association)
    items = @siblings.flat_map do |sib|
      sib.send(association).map { |rec| [rec, sib] }
    end
    return if items.empty?

    ul(class: "tight-list") do
      items.each { |rec, sib| li { yield(rec, sib) } }
    end
  end

  # Renders the trailing "(MO <id>)" link in
  # `<small class="text-muted">` after every sibling row.
  def sibling_attribution(sibling)
    small(class: "text-muted") do
      plain("(")
      a(href: permanent_observation_path(sibling.id)) do
        plain("MO #{sibling.id}")
      end
      plain(")")
    end
  end

  def render_sibling_herbarium_record(record, sibling)
    a(href: herbarium_record_path(record.id)) do
      trusted_html(record.accession_at_herbarium.t)
    end
    whitespace
    sibling_attribution(sibling)
    render_mcp_search_link(record) if record.herbarium.web_searchable?
  end

  def render_mcp_search_link(record)
    br
    span(class: "indent") do
      render(::Components::Link::External.new(
               :herbarium_record_collection.t,
               record.herbarium.mcp_url(record.accession_number)
             ))
    end
  end

  def render_sibling_sequence_archive(sequence)
    plain(" [")
    render(::Components::Link::External.new(
             :show_observation_archive_link.t,
             sequence.accession_url
           ))
    plain("]")
  end
end
