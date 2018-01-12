json.id              object.id
json.type            "name"
json.name            object.real_text_name
json.author          object.author
json.rank            object.rank.to_s.downcase
json.deprecated      object.deprecated ? true : false
json.misspelled      object.is_misspelling? ? true : false
json.citation        object.citation.to_s.tl
json.notes           object.notes.to_s.tpl_nodiv
json.created_at      object.created_at.try(&:utc)
json.updated_at      object.updated_at.try(&:utc)
json.number_of_views object.num_views
json.last_viewed     object.last_view.try(&:utc)
json.ok_for_export   object.ok_for_export ? true : false
if !detail
  json.synonym_id object.synonym_id if object.synonym_id
else
  if object.synonym_id
    json.synonyms (object.synonyms - [object]).map do |synonym|
      {
        id:         synonym.id,
        name:       synonym.real_text_name,
        author:     synonym.author,
        rank:       synonym.rank.to_s.downcase,
        deprecated: synonym.deprecated ? true : false,
        misspelled: synonym.is_misspelling? ? true : false
      }
    end
  end
  unless object.classification.blank?
    parse = Name.parse_classification(object.classification)
    json.parents parse.map do |rank, name|
      {
        name: name,
        rank: rank.to_s.downcase
      }
    end
  end
end
