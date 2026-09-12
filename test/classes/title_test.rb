# frozen_string_literal: true

require("test_helper")

class TitleTest < UnitTestCase
  def test_for_dispatches_to_matching_subclass
    seq = sequences(:local_sequence)

    assert_instance_of(Title::Sequence, Title.for(seq))
  end

  def test_for_falls_back_to_base_for_model_with_no_subclass
    # Publication has no Title:: subclass -- confirm the dispatcher
    # doesn't raise and falls through to the base default.
    pub = publications(:one_pub)

    assert_instance_of(Title, Title.for(pub))
  end

  def test_for_walks_class_hierarchy_for_description_subclasses
    # NameDescription/LocationDescription are concrete subclasses of
    # the abstract Description, where the title logic actually lives.
    # Title.for must resolve to Title::Description via the class
    # hierarchy, not just object.class.name.
    desc = name_descriptions(:agaricus_campestras_desc)

    assert_instance_of(Title::Description, Title.for(desc))
  end

  def test_base_defaults_resolve_type_tag
    pub = publications(:one_pub)
    title = Title.for(pub)

    assert_equal(:publication.ti, title.page_title)
    assert_equal(:publication.ti, title.document_title)
  end

  def test_for_handles_non_abstract_model_objects_gracefully
    # A non-AbstractModel object (anonymous class -> object.class.name
    # is nil) with no matching Title:: subclass -- confirm the
    # dispatcher still returns the base Title rather than raising
    # during the hierarchy walk.
    fake_class = Struct.new(:type_tag)
    fake = fake_class.new(:observation)

    assert_instance_of(Title, Title.for(fake))
  end
end
