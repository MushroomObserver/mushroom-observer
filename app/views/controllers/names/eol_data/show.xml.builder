# frozen_string_literal: true

xml.instruct!(:xml, version: "1.0")
xml.response(
  "xmlns" => "http://www.eol.org/transfer/content/0.2",
  "xmlns:xsd" => "http://www.w3.org/2001/XMLSchema",
  "xmlns:dc" => "http://purl.org/dc/elements/1.1/",
  "xmlns:dcterms" => "http://purl.org/dc/terms/",
  "xmlns:geo" => "http://www.w3.org/2003/01/geo/wgs84_pos#",
  "xmlns:dwc" => "http://rs.tdwg.org/dwc/dwcore/",
  "xmlns:xsi" => "http://www.w3.org/2001/XMLSchema-instance",
  "xsi:schemaLocation" => "http://www.eol.org/transfer/content/0.2 " \
                          "http://services.eol.org/schema/content_0_2.xsd"
) do
  @data.names.each do |taxon|
    xml.taxon do
      xml.dc(:identifier, "#{MO.http_domain}/names/#{taxon.id}")
      xml.dc(:source, "#{MO.http_domain}/names/#{taxon.id}")
      Name.parse_classification(taxon.classification).each do |(rank, name)|
        xml.dwc(rank, name) if MO.eol_ranks.member?(rank)
      end
      xml.dwc(:ScientificName, taxon.real_search_name)
      xml.dcterms(:modified,
                  taxon.updated_at.utc.strftime("%Y-%m-%dT%H:%M:%SZ"))
      citation = taxon.citation
      xml.reference(citation.t) if citation.present?
      refs = []
      @data.descriptions(taxon.id).each do |desc|
        next if desc.refs.blank?

        desc.refs.split(/[\n\r]/).each do |ref|
          ref = ref.strip
          refs << ref.t if ref.present? && ref != citation
        end
      end
      refs.uniq.each { |ref| xml.reference(ref.t) }
      @data.descriptions(taxon.id).each do |desc|
        NameDescription.eol_note_fields.each do |f|
          value = desc.send(f)
          next if value.blank?

          xml.dataObject do
            lang = desc.locale || MO.default_locale
            xml.dc(:identifier, "NameDescription-#{desc.id}-#{f}")
            xml.dataType("http://purl.org/dc/dcmitype/Text")
            xml.mimeType("text/html")
            xml.agent(@data.authors(desc.id), role: "author")
            xml.dcterms(:modified,
                        desc.updated_at.utc.strftime("%Y-%m-%dT%H:%M:%SZ"))
            xml.dc(:title, :"form_names_#{f}".l, "xml:lang" => lang)
            xml.dc(:language, lang)
            xml.license(@data.license_url(desc.license_id))
            xml.dcterms(:rightsHolder, @data.authors(desc.id))
            xml.audience("General public")
            # The following mapping assumes that this is being read in English
            xml.subject(
              "http://rs.tdwg.org/ontology/voc/SPMInfoItems#" \
              "#{:"form_names_#{f}".l.delete(" ")}"
            )

            xml.dc(:description, desc.send(f).tp, "xml:lang" => lang)
            # xml.reviewStatus(desc.review_status)
          end
        end
      end
      @data.images(taxon.id).each do |image|
        # @image_data[taxon.id].each do
        #   |image_id, obs_id, user_id, license_id, created|
        user = @data.rights_holder(image)
        xml.dataObject do
          xml.dc(:identifier, "Image-#{image.id}")
          xml.dataType("http://purl.org/dc/dcmitype/StillImage")
          xml.mimeType("image/jpeg")
          # Illustrations need to be identified
          xml.agent(user, role: "photographer")
          xml.dcterms(:created, Time.zone.parse(image.created_at.to_s).utc.
                                     strftime("%Y-%m-%dT%H:%M:%SZ"))
          xml.license(@data.license_url(image.license_id))
          xml.dcterms(:rightsHolder, user)
          xml.audience("General public")
          xml.dc(:source, "#{MO.http_domain}/images/#{image.id}")
          xml.dc(:description,
                 "Mushroom Observer Image #{image.id}: " \
                 "#{@data.image_to_names(image.id)}",
                 "xml:lang" => "en")
          xml.mediaURL("#{MO.http_domain}/images/640/#{image.id}.jpg")
          # xml.reviewStatus(image.review_status)
        end
      end
    end
    if @max_secs && @timer_start && (Time.zone.now > (@timer_start + @max_secs))
      break
    end
  end
end
