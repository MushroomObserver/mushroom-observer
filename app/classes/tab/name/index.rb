# frozen_string_literal: true

# "All names" index link. Plain InternalLink (no model variant) —
# the original `names_index_tab` matched this shape exactly.
class Tab::Name::Index < Tab::Base
  def title
    :all_objects.t(type: :name)
  end

  def path
    names_path
  end
end
