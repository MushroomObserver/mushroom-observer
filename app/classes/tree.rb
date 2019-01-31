class Tree
  # Searches the screwy ActiveRecord join- and include-style "trees" for a node.
  #
  # NOTE: Symbol, Array and Hash classes have been extended with "has_node?"
  # methods.  It might be more readable to use those as entry points.
  #
  #   BAD:
  #     Tree.has_node?(join, :names)
  #   GOOD:
  #     join.has_node?(:names)
  #
  def self.has_node?(tree, look_for)
    case tree
    when Symbol
      return tree == look_for
    when Array
      tree.each do |val|
        return true if has_node?(val, look_for)
      end
    when Hash
      tree.each_pair do |key, val|
        return true if key == look_for
        return true if has_node?(val, look_for)
      end
    end
    false
  end

  # Extends the screwy ActiveRecord join- and include-style "trees" by adding
  # a single table to hang off a given table.  Can only add a single table,
  # but can build more complicated trees with multiple calls:
  #
  #   BAD:
  #     tree = tree.add_leaf(:a, {:b => :c})
  #   GOOD:
  #     tree = tree.add_leaf(:a, :b)
  #     tree = tree.add_leaf(:b, :c)
  #
  #   BAD:
  #     tree = tree.add_leaf(:a, [:b, :c]):
  #   GOOD:
  #     tree = tree.add_leaf(:a, :b)
  #     tree = tree.add_leaf(:a, :c)
  #
  # NOTE: Symbol, Array and Hash classes have been extended with "add_leaf"
  # methods.  It might be more readable to use those as entry points.
  #
  #   BAD:
  #     self.join = Tree.add_leaf(join, :this, :that)
  #   GOOD:
  #     self.join = join.add_leaf(:this, :that)
  #
  # NOTE: For convenience there is a single-table form of this method which
  # assumes you want to add the given table at the root level.
  #
  #   join.add_leaf(:table)
  #
  # NOTE: There is no Symbol#replace, so there is no way to do an in-place
  # modification of an existing tree if there is any chance that that tree
  # consists only of a single Symbol.  If you *know* your tree is an Array or
  # Hash, then you safely ignore the return value.
  #
  # NOTE: If the tree already contains the leaf (hanging off of the desired
  # parent), then this does nothing.  Thus it is safe to add the same leaf
  # multiple times.
  #
  def self.add_leaf(tree, look_for, add_this = nil)
    case tree
    when Symbol
      if tree == look_for
        return tree unless add_this

        return { look_for => add_this }
      elsif add_this
        return [tree, { look_for => add_this }]
      else
        return [tree, look_for]
      end
    when Array
      tree.each_with_index do |val, i|
        if add_this && has_node?(val, look_for)
          tree[i] = add_leaf(val, look_for, add_this)
          return tree
        elsif val == look_for
          return tree
        end
      end
      if add_this
        tree << { look_for => add_this }
      else
        tree << look_for
      end
      return tree
    when Hash
      unless add_this
        raise "Can't use one-table form of Tree.add_leaf if tree is a Hash!"
      end

      tree.each_pair do |key, val|
        if key == look_for
          case val
          when Symbol
            tree[key] = [val, add_this] if val != add_this
          when Array
            val << add_this unless val.include?(add_this)
          when Hash
            tree[key] = [val, add_this] unless val.key?(add_this)
          end
          return tree
        elsif has_node?(val, look_for)
          tree[key] = add_leaf(val, look_for, add_this)
          return tree
        end
      end
      tree[look_for] = add_this
      return tree
    end
  end
end
