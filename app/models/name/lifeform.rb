class Name < AbstractModel
  ALL_LIFEFORMS = [
    "basidiolichen",
    "lichen",
    "lichen_ally",
    "lichenicolous"
  ].freeze

  def self.all_lifeforms
    ALL_LIFEFORMS
  end

  # This will include "lichen", "lichenicolous" and "lichen-ally" -- the usual
  # set of taxa lichenologists are interested in.
  def is_lichen?
    lifeform.include?("lichen")
  end

  # This excludes "lichen" but includes "mushroom" (so that truly lichenized
  # basidiolichens with mushroom fruiting bodies are included).
  def not_lichen?
    !lifeform.include?(" lichen ")
  end

  validate :validate_lifeform

  # Sorts and uniquifies the lifeform words, and complains about any that are
  # not recognized.  It adds an extra space before and after to ensure that it
  # is easy to search for entire words instead of just substrings.  That is,
  # one can do this:
  #
  #   lifeform.include(" word ")
  #
  # and be confident that it will not skip "word" at the beginning or end,
  # and will not match "compoundword".
  def validate_lifeform
    words = lifeform.to_s.split(" ").sort.uniq
    self.lifeform = words.any? ? " #{words.join(" ")} " : " "
    unknown_words = words - ALL_LIFEFORMS
    return unless unknown_words.any?

    unknown_words = unknown_words.map(&:inspect).join(", ")
    errors.add(:lifeform, :validate_invalid_lifeform.t(words: unknown_words))
  end

  # Add lifeform (one word only) to all children.
  def propagate_add_lifeform(lifeform)
    concat_str = Name.connection.quote("#{lifeform} ")
    search_str = Name.connection.quote("% #{lifeform} %")
    Name.connection.execute(%(
      UPDATE names SET lifeform = CONCAT(lifeform, #{concat_str})
      WHERE id IN (#{all_children.map(&:id).join(",")})
        AND lifeform NOT LIKE #{search_str}
    ))
    Name.connection.execute(%(
      UPDATE observations SET lifeform = CONCAT(lifeform, #{concat_str})
      WHERE name_id IN (#{all_children.map(&:id).join(",")})
        AND lifeform NOT LIKE #{search_str}
    ))
  end

  # Remove lifeform (one word only) from all children.
  def propagate_remove_lifeform(lifeform)
    replace_str = Name.connection.quote(" #{lifeform} ")
    search_str  = Name.connection.quote("% #{lifeform} %")
    Name.connection.execute(%(
      UPDATE names SET lifeform = REPLACE(lifeform, #{replace_str}, " ")
      WHERE id IN (#{all_children.map(&:id).join(",")})
        AND lifeform LIKE #{search_str}
    ))
    Name.connection.execute(%(
      UPDATE observations SET lifeform = REPLACE(lifeform, #{replace_str}, " ")
      WHERE name_id IN (#{all_children.map(&:id).join(",")})
        AND lifeform LIKE #{search_str}
    ))
  end
end
