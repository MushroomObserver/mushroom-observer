# frozen_string_literal: true

# Layout CSS-class slot setters + defaulters, mixed into
# `Views::FullPageBase`.
#
# Action views call the setters from their `view_template`
# (`container_class(:wide)`, `column_classes(:nine_three)`, etc.) to
# populate `content_for(:container_class)` / `(:left_columns)` /
# `(:right_columns)` / `(:content_padding)`. `Views::FullPageBase#
# around_template` runs the matching `default_*` defaulters AFTER
# the action's `view_template` has finished, applying default values
# to any slot the action didn't set. By the time
# `Views::Layouts::Application` renders, every slot is guaranteed
# to be populated — the layout just reads, no defaulter logic on its
# side.
module Views::FullPageBase::LayoutClasses
  # ----- Width of the layout's main content container --------------

  def container_class(container = :text)
    container ||= :text
    content_for(:container_class, flush: true) do
      case container
      when :text       then "container-text"
      when :text_image then "container-text-image"
      when :wide       then "container-wide"
      else                  "container-full"
      end
    end
  end

  def default_container_class
    return if content_for?(:container_class)

    container_class
  end

  # ----- Left + right column classes (sync title bar with body) ----

  def column_classes(columns = :twelve)
    content_for(:left_columns, flush: true) do
      left_column_class_for(columns)
    end
    content_for(:right_columns, flush: true) do
      right_column_class_for(columns)
    end
  end

  def default_column_classes
    return if content_for?(:left_columns)

    column_classes
  end

  # ----- Vertical padding inside the main container ----------------

  def content_padding(content_has = nil)
    content_has ||= action_name.in?(%w[index show]) ? :panels : :no_panels
    content_for(:content_padding, flush: true) do
      content_has == :no_panels ? "p-3" : "p-0"
    end
  end

  def default_content_padding
    return if content_for?(:content_padding)

    content_padding
  end

  private

  def left_column_class_for(columns)
    case columns
    when :nine_three  then class_names("col-xs-12 col-md-9 col-lg-8")
    when :eight_four  then class_names("col-xs-12 col-md-8 col-lg-7")
    when :seven_five  then class_names("col-xs-12 col-md-7")
    when :six         then class_names("col-xs-12 col-md-6 col-lg-8")
    when :six_even    then class_names("col-xs-12 col-lg-6")
    else                   class_names("col-xs-12")
    end
  end

  def right_column_class_for(columns)
    case columns
    when :nine_three  then class_names("col-xs-12 col-md-3 col-lg-4")
    when :eight_four  then class_names("col-xs-12 col-md-4 col-lg-5")
    when :seven_five  then class_names("col-xs-12 col-md-5")
    when :six         then class_names("col-xs-12 col-md-6 col-lg-4")
    when :six_even    then class_names("col-xs-12 col-lg-6")
    else                   class_names("col-xs-12")
    end
  end
end
