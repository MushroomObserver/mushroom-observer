# frozen_string_literal: true

json.id(object.id)
json.type("name")
json.name(object.real_text_name.to_s)
json.author(object.author.to_s) if object.author.present?
json.rank(object.rank.to_s.downcase)
json.deprecated(object.deprecated ? true : false)
json.misspelled(object.is_misspelling? ? true : false)
json.citation(object.citation.to_s.tl) if object.citation.present?
json.notes(object.notes.to_s.tpl_nodiv) if object.notes.present?
json.created_at(object.created_at.try(&:utc))
json.updated_at(object.updated_at.try(&:utc))
json.number_of_views(object.num_views)
json.last_viewed(object.last_view.try(&:utc))
json.ok_for_export(object.ok_for_export ? true : false)
if !detail
  json.synonym_id(object.synonym_id) if object.synonym_id
else
  if object.synonym_id
    json.synonyms((object.synonyms - [object]).map { |x| json_name(x) })
  end
  if object.classification.present?
    parse = Name.parse_classification(object.classification)
    json.parents(parse.map do |rank, name|
      { name: name, rank: rank.to_s.downcase }
    end)
  end
  if object.comments.any?
    json.comments(object.comments.map { |x| json_comment(x) })
  end
end
