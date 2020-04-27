xml.instruct! :xml, version: "1.0"
xml.response(
  "xmlns" => "http://www.eol.org/transfer/content/0.2",
  "xmlns:xsd" => "http://www.w3.org/2001/XMLSchema",
  "xmlns:dc" => "http://purl.org/dc/elements/1.1/",
  "xmlns:dcterms" => "http://purl.org/dc/terms/",
  "xmlns:geo" => "http://www.w3.org/2003/01/geo/wgs84_pos#",
  "xmlns:dwc" => "http://rs.tdwg.org/dwc/dwcore/",
  "xmlns:xsi" => "http://www.w3.org/2001/XMLSchema-instance",
  "xsi:schemaLocation" => "http://www.eol.org/transfer/content/0.2 "\
                          "http://services.eol.org/schema/content_0_2.xsd"
) {
  for taxon in @data.names
    xml.taxon do
      xml.dc(:identifier, "#{MO.http_domain}/names/show_name/#{taxon.id}")
      xml.dc(:source, "#{MO.http_domain}/names/show_name/#{taxon.id}")
      for (rank, name) in Name.parse_classification(taxon.classification)
        if MO.eol_ranks.member?(rank)
          xml.dwc(rank, name)
        end
      end
      xml.dwc(:ScientificName, taxon.real_search_name)
      xml.dcterms(:modified,
                  taxon.updated_at.utc.strftime("%Y-%m-%dT%H:%M:%SZ"))
      citation = taxon.citation
      if citation.present?
        xml.reference(citation.t)
      end
      refs = []
      @data.descriptions(taxon.id).each do |desc|
        next unless desc.refs.present?

        desc.refs.split(/[\n\r]/).each do |ref|
          ref = ref.strip
          refs << ref.t if ref.present? && ref != citation
        end
      end
      refs.uniq.each { |ref| xml.reference(ref.t) }
      for desc in @data.descriptions(taxon.id)
        for f in NameDescription.eol_note_fields
          value = desc.send(f)
          next unless value.present?

          xml.dataObject do
            lang = desc.locale || MO.default_locale
            xml.dc(:identifier, "NameDescription-#{desc.id}-#{f}")
            xml.dataType("http://purl.org/dc/dcmitype/Text")
            xml.mimeType("text/html")
            xml.agent(@data.authors(desc.id), role: "author")
            xml.dcterms(:modified,
                        desc.updated_at.utc.strftime("%Y-%m-%dT%H:%M:%SZ"))
            xml.dc(:title, "form_names_#{f}".to_sym.l, "xml:lang" => lang)
            xml.dc(:language, lang)
            xml.license(@data.license_url(desc.license_id))
            xml.dcterms(:rightsHolder, @data.authors(desc.id))
            xml.audience("General public")

            # The following mapping assumes that this is being read in English
            xml.subject("http://rs.tdwg.org/ontology/voc/SPMInfoItems#%s" %
                        "form_names_#{f}".to_sym.l.delete(" "))

            xml.dc(:description, desc.send(f).tp, "xml:lang" => lang)
            # xml.reviewStatus(desc.review_status)
          end
        end
      end
      for image in @data.images(taxon.id)
        # for image_id, obs_id, user_id,
        #     license_id, created in @image_data[taxon.id]
        user = @data.rights_holder(image)
        xml.dataObject do
          xml.dc(:identifier, "Image-#{image.id}")
          xml.dataType("http://purl.org/dc/dcmitype/StillImage")
          xml.mimeType("image/jpeg")
          # Illustrations need to be identified
          xml.agent(user, role: "photographer")
          xml.dcterms(:created, Time.parse(image.created_at.to_s).utc.
                                     strftime("%Y-%m-%dT%H:%M:%SZ"))
          xml.license(@data.license_url(image.license_id))
          xml.dcterms(:rightsHolder, user)
          xml.audience("General public")
          xml.dc(:source, "#{MO.http_domain}/image/show_image/#{image.id}")
          xml.dc(:description,
                 "Mushroom Observer Image #{image.id}: "\
                 "#{@data.image_to_names(image.id)}",
                 "xml:lang" => "en")
          xml.mediaURL("#{MO.http_domain}/images/640/#{image.id}.jpg")
          # xml.reviewStatus(image.review_status)
        end
      end
    end
    if @max_secs && @timer_start && (Time.now > (@timer_start + @max_secs))
      break
    end
  end
}
