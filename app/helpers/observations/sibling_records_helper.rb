# frozen_string_literal: true

# Renders read-only records from sibling observations in an occurrence.
# Used on the observation show page to display aggregated data.
module Observations::SiblingRecordsHelper
  def sibling_collection_numbers(siblings)
    sibling_record_list(siblings, :collection_numbers) do |cn, sib|
      [link_to(cn.format_name, collection_number_path(cn.id)),
       sibling_attribution(sib)].safe_join(" ")
    end
  end

  def sibling_herbarium_records(siblings)
    sibling_record_list(siblings, :herbarium_records) do |hr, sib|
      sibling_herbarium_record_content(hr, sib)
    end
  end

  def sibling_sequences(siblings)
    sibling_record_list(siblings, :sequences) do |seq, sib|
      parts = [link_to(seq.format_name, sequence_path(seq.id))]
      if seq.deposit?
        parts << link_to(seq.bases_trimmed, seq.deposit_url,
                         target: "_blank", rel: "noopener")
      end
      parts << sibling_attribution(sib)
      parts.safe_join(" ")
    end
  end

  # Returns raw <li> tags (no wrapping <ul>) for integration into
  # the existing external_links partial list.
  def sibling_external_link_items(siblings)
    items = siblings.flat_map do |sib|
      sib.external_links.map { |el| [el, sib] }
    end
    return "".html_safe if items.empty?

    items.map do |el, sib|
      tag.li { sibling_external_link_content(el, sib) }
    end.safe_join
  end

  private

  def sibling_record_list(siblings, association)
    items = siblings.flat_map do |sib|
      sib.send(association).map { |rec| [rec, sib] }
    end
    return if items.empty?

    tag.ul(class: "tight-list") do
      items.map { |rec, sib| tag.li { yield(rec, sib) } }.
        safe_join
    end
  end

  def sibling_herbarium_record_content(record, sibling)
    parts = [link_to(record.accession_at_herbarium.t,
                     herbarium_record_path(record.id)),
             sibling_attribution(sibling)]
    if record.herbarium.web_searchable?
      parts << tag.br
      parts << mcp_search_link(record)
    end
    parts.safe_join(" ")
  end

  def mcp_search_link(record)
    tag.span(class: "indent") do
      link_to(:herbarium_record_collection.t,
              record.herbarium.mcp_url(record.accession_number),
              target: "_blank", rel: "noopener")
    end
  end

  def sibling_external_link_content(ext_link, sibling)
    link_text = if ext_link.external_site.name == "iNaturalist"
                  inat_label(ext_link)
                else
                  ext_link.site_name
                end
    [link_to(link_text, ext_link.url),
     sibling_attribution(sibling)].safe_join(" ")
  end

  def inat_label(ext_link)
    "iNat #{ext_link.url.sub(ext_link.external_site.base_url, "")}"
  end

  def sibling_attribution(sibling)
    obs_link = link_to("MO #{sibling.id}",
                       permanent_observation_path(sibling.id))
    tag.small("(".html_safe + obs_link + ")".html_safe,
              class: "text-muted")
  end
end
