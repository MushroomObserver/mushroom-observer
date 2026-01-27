# frozen_string_literal: true

# Form object for editing Name lifeform tags
# Attributes are dynamically defined for each lifeform in Name::ALL_LIFEFORMS
class FormObject::Lifeform < FormObject::Base
  # Define an attribute for each lifeform word
  Name::Lifeform::ALL_LIFEFORMS.each do |word|
    attribute word.to_sym, :boolean, default: false
  end

  # Initialize from a Name's lifeform string
  def self.from_name(name)
    attrs = {}
    Name::Lifeform::ALL_LIFEFORMS.each do |word|
      attrs[word.to_sym] = name.lifeform.include?(" #{word} ")
    end
    new(attrs)
  end
end
