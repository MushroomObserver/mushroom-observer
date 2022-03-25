# frozen_string_literal: true

class Name < AbstractModel
  ALL_LIFEFORMS = %w[
    basidiolichen
    lichen
    lichen_ally
    lichenicolous
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
    # concat_str = Name.connection.quote_string("#{lifeform} ")
    # search_str = Name.connection.quote_string("% #{lifeform} %")

    # for type in %w[name observation] do
    #   update_manager = arel_update_add_lifeform(
    #     type, concat_str, search_str
    #   )
    #   # puts(all_children.map(&:id).inspect)
    #   # puts(update_manager.to_sql)
    #   Name.connection.update(update_manager.to_sql)
    # end
    name_ids = all_children.map(&:id)

    Name.where(id: name_ids).
      where(Name[:lifeform].does_not_match("% #{lifeform} %")).
      update_all(lifeform: Name[:lifeform] + "#{lifeform} ")

    Observation.where(name_id: name_ids).
      where(Observation[:lifeform].does_not_match("% #{lifeform} %")).
      update_all(lifeform: Observation[:lifeform] + "#{lifeform} ")
  end

  # Remove lifeform (one word only) from all children.
  def propagate_remove_lifeform(lifeform)
    replace_str = Name.connection.quote_string(" #{lifeform} ")
    search_str  = Name.connection.quote_string("% #{lifeform} %")

    for type in %w[name observation] do
      update_manager = arel_update_remove_lifeform(
        type, replace_str, search_str
      )
      # puts(update_manager.to_sql)
      Name.connection.update(update_manager.to_sql)
    end
  end

  private

  # def arel_update_add_lifeform(type, concat_str, search_str)
  #   table = type.camelize.constantize.arel_table
  #   id_column = type == "name" ? :id : :name_id
  #   concat_sql = arel_function_concat_lifeform(table, concat_str)
  #   # puts(concat_sql)

  #   # UPDATE names SET lifeform = CONCAT(lifeform, #{concat_str})
  #   # WHERE id IN (#{all_children.map(&:id).join(",")})
  #   #   AND lifeform NOT LIKE #{search_str}

  #   # UPDATE observations SET lifeform = CONCAT(lifeform, #{concat_str})
  #   # WHERE name_id IN (#{all_children.map(&:id).join(",")})
  #   #   AND lifeform NOT LIKE #{search_str}
  #   Arel::UpdateManager.new.
  #     table(table).
  #     where(table[id_column.to_sym].in(all_children.map(&:id)).
  #           and(table[:lifeform].does_not_match(search_str))).
  #     set([[table[:lifeform], concat_sql]])
  # end

  # def arel_function_concat_lifeform(table, concat_str)
  #   Arel::Nodes::SqlLiteral.new((table[:lifeform] + concat_str).to_sql)
  #   # Arel::Nodes::SqlLiteral.new(
  #   #   Arel::Nodes::NamedFunction.new(
  #   #     "CONCAT", [table[:lifeform], Arel.sql(concat_str)]
  #   #   ).to_sql
  #   # )
  # end

  def arel_update_remove_lifeform(type, replace_str, search_str)
    table = type.camelize.constantize.arel_table
    id_column = type == "name" ? :id : :name_id
    replace_sql = arel_function_replace_lifeform(table, replace_str)

    # UPDATE names SET lifeform = REPLACE(lifeform, #{replace_str}, " ")
    # WHERE id IN (#{all_children.map(&:id).join(",")})
    #   AND lifeform LIKE #{search_str}

    # UPDATE observations SET lifeform = REPLACE(lifeform, #{replace_str}, " ")
    # WHERE name_id IN (#{all_children.map(&:id).join(",")})
    #   AND lifeform LIKE #{search_str}
    Arel::UpdateManager.new.
      table(table).
      where(table[id_column.to_sym].in(all_children.map(&:id)).
            and(table[:lifeform].matches(search_str))).
      set([[table[:lifeform], replace_sql]])
  end

  def arel_function_replace_lifeform(table, replace_str)
    Arel::Nodes::SqlLiteral.new(
      Arel::Nodes::NamedFunction.new(
        "REPLACE",
        [table[:lifeform],
         Arel::Nodes.build_quoted(replace_str),
         Arel::Nodes.build_quoted(" ")]
      ).to_sql
    )
  end
end
