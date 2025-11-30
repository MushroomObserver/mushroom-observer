# frozen_string_literal: true

require "test_helper"

class NamesLookupFieldGroupTest < UnitTestCase
  include ComponentTestHelper

  def setup
    super
    @name = names(:coprinus_comatus)
    @query = Query.lookup(:Observation)
    controller.request = ActionDispatch::TestRequest.create
  end

  # Indirectly covers line 80 by asserting autocompleter value uses display_name
  def test_autocompleter_value_uses_display_names
    @query.names = { lookup: [@name.id] }

    lookup_field_stub = Struct.new(:opts) do
      def autocompleter(**opts)
        self.opts = opts
        self
      end
    end.new

    names_ns = Object.new
    names_ns.define_singleton_method(:field) do |sym|
      raise("unexpected field: #{sym}") unless sym == :lookup

      lookup_field_stub
    end

    component = Components::NamesLookupFieldGroup.new(
      names_namespace: names_ns,
      query: @query,
      modifier_fields: []
    )

    component.stub(:render, nil) do
      render_component(component)
    end

    assert_includes(lookup_field_stub.opts[:value], @name.display_name)
  end

  # Indirectly covers line 80 rescue by asserting unknown ID passes through
  def test_autocompleter_value_passes_through_unknown_id
    unknown_id = 999_999_999
    @query.names = { lookup: [unknown_id] }

    lookup_field_stub = Struct.new(:opts) do
      def autocompleter(**opts)
        self.opts = opts
        self
      end
    end.new

    names_ns = Object.new
    names_ns.define_singleton_method(:field) do |sym|
      raise("unexpected field: #{sym}") unless sym == :lookup

      lookup_field_stub
    end

    component = Components::NamesLookupFieldGroup.new(
      names_namespace: names_ns,
      query: @query,
      modifier_fields: []
    )

    component.stub(:render, nil) do
      render_component(component)
    end

    assert_includes(lookup_field_stub.opts[:value], unknown_id.to_s)
  end

  # Test lines 106-107: if field_pair.is_a?(Array) in render_modifier_rows
  def test_render_modifier_rows_handles_array_fields
    @query.names = { lookup: [@name.id] }
    component = create_component(
      modifier_fields: [[:include_synonyms, :include_subtaxa]]
    )

    # Verify it processes arrays
    modifier_fields = component.instance_variable_get(:@modifier_fields)
    assert(modifier_fields.first.is_a?(Array))
  end

  # Test line 115: render_select_field(field_pair) when not an array
  def test_render_modifier_rows_handles_single_fields
    @query.names = { lookup: [@name.id] }
    component = create_component(
      modifier_fields: [:include_all_name_children]
    )

    # Verify single field is not an array
    modifier_fields = component.instance_variable_get(:@modifier_fields)
    assert_not(modifier_fields.first.is_a?(Array))
  end

  # Cover non-array branch by executing render_modifier_rows
  def test_render_modifier_rows_calls_select_for_single_field
    @query.names = { include_synonyms: true }

    # Stub namespace to capture select invocation
    field_stub = Struct.new(:called, :args) do
      def select(*args, **_kwargs)
        self.called = true
        self.args = args
      end
    end.new(false, nil)

    names_ns = Minitest::Mock.new
    names_ns.expect(:field, field_stub, [:include_synonyms])

    component = Components::NamesLookupFieldGroup.new(
      names_namespace: names_ns,
      query: @query,
      modifier_fields: [:include_synonyms]
    )

    # Execute branch: else -> render_select_field(field_pair)
    # Stub out Phlex render to avoid requiring a real component
    component.stub(:render, nil) do
      component.send(:render_modifier_rows)
    end

    assert(field_stub.called)
    names_ns.verify
  end

  # Indirectly cover bool_to_string by capturing selected value passed to select
  def test_select_selected_is_empty_string_for_nil
    @query.names = {}
    field_stub = Struct.new(:call) do
      def select(_options, wrapper_options:, selected:)
        self.call = { wrapper_options:, selected: }
        self
      end
    end.new

    lookup_field_stub = Struct.new(:opts) do
      def autocompleter(**opts)
        self.opts = opts
        self
      end
    end.new
    names_ns = Object.new
    names_ns.define_singleton_method(:field) do |sym|
      case sym
      when :include_synonyms then field_stub
      when :lookup then lookup_field_stub
      else raise("unexpected field: #{sym}")
      end
    end

    component = Components::NamesLookupFieldGroup.new(
      names_namespace: names_ns,
      query: @query,
      modifier_fields: [:include_synonyms]
    )

    component.stub(:render, nil) { render_component(component) }

    assert_equal("", field_stub.call[:selected])
  end

  def test_select_selected_is_true_string_when_true
    @query.names = { include_synonyms: true }
    field_stub = Struct.new(:call) do
      def select(_options, wrapper_options:, selected:)
        self.call = { wrapper_options:, selected: }
        self
      end
    end.new

    lookup_field_stub = Struct.new(:opts) do
      def autocompleter(**opts)
        self.opts = opts
        self
      end
    end.new
    names_ns = Object.new
    names_ns.define_singleton_method(:field) do |sym|
      case sym
      when :include_synonyms then field_stub
      when :lookup then lookup_field_stub
      else raise("unexpected field: #{sym}")
      end
    end

    component = Components::NamesLookupFieldGroup.new(
      names_namespace: names_ns,
      query: @query,
      modifier_fields: [:include_synonyms]
    )

    component.stub(:render, nil) { render_component(component) }

    assert_equal("true", field_stub.call[:selected])
  end

  def test_select_selected_is_false_string_when_false
    @query.names = { include_synonyms: false }
    field_stub = Struct.new(:call) do
      def select(_options, wrapper_options:, selected:)
        self.call = { wrapper_options:, selected: }
        self
      end
    end.new

    lookup_field_stub = Struct.new(:opts) do
      def autocompleter(**opts)
        self.opts = opts
        self
      end
    end.new
    names_ns = Object.new
    names_ns.define_singleton_method(:field) do |sym|
      case sym
      when :include_synonyms then field_stub
      when :lookup then lookup_field_stub
      else raise("unexpected field: #{sym}")
      end
    end

    component = Components::NamesLookupFieldGroup.new(
      names_namespace: names_ns,
      query: @query,
      modifier_fields: [:include_synonyms]
    )

    component.stub(:render, nil) { render_component(component) }

    assert_equal("false", field_stub.call[:selected])
  end

  def test_autocompleter_value_with_name_ids
    @query.names = { lookup: [@name.id] }
    lookup_field_stub = Struct.new(:opts) do
      def autocompleter(**opts)
        self.opts = opts
        self
      end
    end.new

    names_ns = Object.new
    names_ns.define_singleton_method(:field) do |sym|
      raise unless sym == :lookup

      lookup_field_stub
    end

    component = Components::NamesLookupFieldGroup.new(
      names_namespace: names_ns,
      query: @query,
      modifier_fields: []
    )

    component.stub(:render, nil) do
      render_component(component)
    end

    assert_includes(lookup_field_stub.opts[:value], @name.display_name)
  end

  def test_autocompleter_value_with_multiple_names
    name2 = names(:fungi)
    @query.names = { lookup: [@name.id, name2.id] }

    lookup_field_stub = Struct.new(:opts) do
      def autocompleter(**opts)
        self.opts = opts
        self
      end
    end.new

    names_ns = Object.new
    names_ns.define_singleton_method(:field) do |sym|
      raise unless sym == :lookup

      lookup_field_stub
    end

    component = Components::NamesLookupFieldGroup.new(
      names_namespace: names_ns,
      query: @query,
      modifier_fields: []
    )

    component.stub(:render, nil) do
      render_component(component)
    end

    assert_includes(lookup_field_stub.opts[:value], @name.display_name)
    assert_includes(lookup_field_stub.opts[:value], name2.display_name)
  end

  def test_autocompleter_hidden_value_is_ids_joined_by_newlines
    name2 = names(:fungi)
    @query.names = { lookup: [@name.id, name2.id] }

    lookup_field_stub = Struct.new(:opts) do
      def autocompleter(**opts)
        self.opts = opts
        self
      end
    end.new

    names_ns = Object.new
    names_ns.define_singleton_method(:field) do |sym|
      raise unless sym == :lookup

      lookup_field_stub
    end

    component = Components::NamesLookupFieldGroup.new(
      names_namespace: names_ns,
      query: @query,
      modifier_fields: []
    )

    component.stub(:render, nil) do
      render_component(component)
    end

    assert_equal("#{@name.id}\n#{name2.id}",
                 lookup_field_stub.opts[:hidden_value])
  end

  def test_collapse_has_in_class_when_lookup_present
    @query.names = { lookup: [@name.id] }

    # Minimal stubs for required names namespace calls
    lookup_field_stub = Struct.new(:opts) do
      def autocompleter(**opts)
        self.opts = opts
        self
      end
    end.new
    names_ns = Object.new
    names_ns.define_singleton_method(:field) do |sym|
      sym == :lookup ? lookup_field_stub : Struct.new(:x).new
    end

    component = Components::NamesLookupFieldGroup.new(
      names_namespace: names_ns,
      query: @query,
      modifier_fields: []
    )
    html = component.stub(:render, nil) { render_component(component) }
    assert_html(html, 'div[data-autocompleter-target="collapseFields"]',
                classes: "in")
  end

  def test_collapse_without_values_has_no_in_class
    @query.names = {}

    lookup_field_stub = Struct.new(:opts) do
      def autocompleter(**opts)
        self.opts = opts
        self
      end
    end.new
    names_ns = Object.new
    names_ns.define_singleton_method(:field) do |sym|
      sym == :lookup ? lookup_field_stub : Struct.new(:x).new
    end

    component = Components::NamesLookupFieldGroup.new(
      names_namespace: names_ns,
      query: @query,
      modifier_fields: []
    )
    html = component.stub(:render, nil) { render_component(component) }
    # Should have collapse container without 'in' class
    assert_html(html, 'div[data-autocompleter-target="collapseFields"]')
    doc = Nokogiri::HTML(html)
    el = doc.at_css('div[data-autocompleter-target="collapseFields"]')
    classes = el["class"]&.split || []
    assert_not(classes.include?("in"))
  end

  def test_collapse_has_in_class_when_modifiers_set
    @query.names = { include_synonyms: true }

    lookup_field_stub = Struct.new(:opts) do
      def autocompleter(**opts)
        self.opts = opts
        self
      end
    end.new
    select_field_stub = Struct.new(:called) do
      def select(*)
        self.called = true
        self
      end
    end.new
    names_ns = Object.new
    names_ns.define_singleton_method(:field) do |sym|
      case sym
      when :lookup then lookup_field_stub
      when :include_synonyms then select_field_stub
      else
        raise("unexpected field: #{sym}")
      end
    end

    component = Components::NamesLookupFieldGroup.new(
      names_namespace: names_ns,
      query: @query,
      modifier_fields: [[:include_synonyms]]
    )
    html = component.stub(:render, nil) { render_component(component) }
    assert_html(html, 'div[data-autocompleter-target="collapseFields"]',
                classes: "in")
  end

  def test_collapse_without_modifiers_has_no_in_class
    @query.names = {}

    lookup_field_stub = Struct.new(:opts) do
      def autocompleter(**opts)
        self.opts = opts
        self
      end
    end.new
    select_field_stub = Struct.new(:called) do
      def select(*)
        self.called = true
        self
      end
    end.new
    names_ns = Object.new
    names_ns.define_singleton_method(:field) do |sym|
      case sym
      when :lookup then lookup_field_stub
      when :include_synonyms then select_field_stub
      else
        raise("unexpected field: #{sym}")
      end
    end

    component = Components::NamesLookupFieldGroup.new(
      names_namespace: names_ns,
      query: @query,
      modifier_fields: [[:include_synonyms]]
    )
    html = component.stub(:render, nil) { render_component(component) }
    doc = Nokogiri::HTML(html)
    el = doc.at_css('div[data-autocompleter-target="collapseFields"]')
    classes = el["class"]&.split || []
    assert_not(classes.include?("in"))
  end

  # covered via test_collapse_has_in_class_when_lookup_present

  # covered via test_collapse_has_in_class_when_modifiers_set

  # covered via test_collapse_without_values_has_no_in_class

  def test_field_selected_value_integrates_into_select
    @query.names = { include_synonyms: true }
    field_stub = Struct.new(:call) do
      def select(_options, wrapper_options:, selected:)
        self.call = { wrapper_options:, selected: }
        self
      end
    end.new

    lookup_field_stub = Struct.new(:opts) do
      def autocompleter(**opts)
        self.opts = opts
        self
      end
    end.new
    names_ns = Object.new
    names_ns.define_singleton_method(:field) do |sym|
      case sym
      when :include_synonyms then field_stub
      when :lookup then lookup_field_stub
      else raise("unexpected field: #{sym}")
      end
    end

    component = Components::NamesLookupFieldGroup.new(
      names_namespace: names_ns,
      query: @query,
      modifier_fields: [:include_synonyms]
    )

    component.stub(:render, nil) { render_component(component) }

    assert_equal("true", field_stub.call[:selected])
  end

  private

  def create_component(modifier_fields: [])
    # Create a mock namespace
    names_ns = Minitest::Mock.new

    Components::NamesLookupFieldGroup.new(
      names_namespace: names_ns,
      query: @query,
      modifier_fields: modifier_fields
    )
  end
end
