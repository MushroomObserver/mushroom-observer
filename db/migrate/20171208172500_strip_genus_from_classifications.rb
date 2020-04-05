class StripGenusFromClassifications < ActiveRecord::Migration[4.2]
  def up
    strip_pattern = /\s*(Genus|Species|Subspecies|Variety|Form):.*\z/m

    # Stripping names...
    Name.connection.select_rows(%(
      SELECT id, classification
      FROM names
      WHERE classification REGEXP "(Genus|Species|Subspecies|Variety|Form|Group):"
    )).each do |id, str|
      str.sub!(strip_pattern, "")
      str = Name.connection.quote(str)
      Name.connection.execute(%(
        UPDATE names SET classification = #{str} WHERE id = #{id}
      ))
    end

    # Stripping name_descriptions...
    Name.connection.select_rows(%(
      SELECT id, classification
      FROM name_descriptions
      WHERE classification REGEXP "(Genus|Species|Subspecies|Variety|Form|Group):"
    )).each do |id, str|
      str.sub!(strip_pattern, "")
      str = Name.connection.quote(str)
      Name.connection.execute(%(
        UPDATE name_descriptions SET classification = #{str} WHERE id = #{id}
      ))
    end

    Language.connection.select_rows(%(
      SELECT id, text FROM translation_strings
      WHERE tag = "form_names_classification_help"
    )).each do |id, old_text|
      new_text = old_text.sub(strip_pattern, "")
      next if old_text == new_text
      new_text = Language.connection.quote(new_text)
      Language.connection.execute(%(
        UPDATE translation_strings SET text = #{new_text} WHERE id = #{id}
      ))
    end
  end

  def down
  end
end
