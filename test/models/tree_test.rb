require "test_helper"

class TreeTest < UnitTestCase
  def test_has_node?
    tree = :foo
    assert_true(tree.has_node?(:foo))
    assert_false(tree.has_node?(:spam))

    tree = [:foo, :bar]
    assert_true(tree.has_node?(:foo))
    assert_true(tree.has_node?(:bar))
    assert_false(tree.has_node?(:spam))

    tree = { foo: :bar, one: :two }
    assert_true(tree.has_node?(:foo))
    assert_true(tree.has_node?(:bar))
    assert_true(tree.has_node?(:one))
    assert_true(tree.has_node?(:two))
    assert_false(tree.has_node?(:spam))

    tree = [{ foo: :bar },
            :scalar,
            { glue: [:one, :two] },
            { top: { middle: :leaf } }]
    [
      :foo,
      :bar,
      :scalar,
      :glue,
      :one,
      :two,
      :top,
      :middle,
      :leaf
    ].each do |node|
        assert_true(tree.has_node?(node), "Tree is missing #{node.inspect}!")
      end
    assert_false(tree.has_node?(:spam))
  end

  def test_add_node_to_scalar
    assert_equal(:foo, :foo.add_leaf(:foo))
    assert_equal([:foo, :bar], :foo.add_leaf(:bar))
    assert_equal({ foo: :bar }, :foo.add_leaf(:foo, :bar))
    assert_equal([:spam, { foo: :bar }], :spam.add_leaf(:foo, :bar))
  end

  def test_add_node_to_array
    assert_equal([:foo], [].add_leaf(:foo))
    assert_equal([:foo], [:foo].add_leaf(:foo))
    assert_equal([:foo, :bar], [:foo].add_leaf(:bar))
    assert_equal([{ foo: :bar }], [].add_leaf(:foo, :bar))
    assert_equal([{ foo: :bar }], [:foo].add_leaf(:foo, :bar))
    assert_equal([:spam, { foo: :bar }], [:spam].add_leaf(:foo, :bar))
  end

  def test_add_node_to_hash
    assert_raises(RuntimeError) { {}.add_leaf(:foo) }
    assert_equal({ foo: :bar }, {}.add_leaf(:foo, :bar))
    assert_equal({ foo: :bar }, { foo: :bar }.add_leaf(:foo, :bar))
    assert_equal({ foo: [:spam, :bar] }, { foo: :spam }.add_leaf(:foo, :bar))
    assert_equal({ one: :two, foo: :bar }, { one: :two }.add_leaf(:foo, :bar))
  end

  def test_add_node_to_lower_level
    assert_equal({ one: { two: :three } }, { one: :two }.add_leaf(:two, :three))
    assert_equal({ one: { two: { three: :four } } },
                 { one: { two: :three } }.add_leaf(:three, :four))
    assert_equal({ one: { two: :three } },
                 { one: { two: :three } }.add_leaf(:two, :three))
    assert_equal({ one: [:two, { three: :four }] },
                 { one: [:two, :three] }.add_leaf(:three, :four))
  end
end
