xml.tag!(tag,
  :id => object.id,
  :url => object.show_url,
  :type => 'sequence'
) do
    xml_integer(xml, :observation, object.observation.id)
    xml_integer(xml, :user, object.user.id)
    xml_string(xml, :locus, object.locus.truncate(object.locus_width))
    xml_string(xml, :archive, object.archive)
    xml_string(xml, :accession, object.accession)
  if detail
    xml_string(xml, :bases, object.bases)
    xml_string(xml, :notes, object.notes)
  end
end
