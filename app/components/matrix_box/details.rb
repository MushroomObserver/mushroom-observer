# frozen_string_literal: true

# Matrix box details section component.
#
# Renders the panel-body section containing what/where/when/who information,
# identify UI, and source credit for a matrix box item.
#
# @example
#   render MatrixBox::Details.new(
#     data: render_data,
#     user: @user,
#     identify: true
#   )
class Components::MatrixBox::Details < Components::Base
  include Phlex::Rails::Helpers::LinkTo
  include Phlex::Rails::Helpers::ClassNames

  prop :data, Hash
  prop :user, _Nilable(User), default: nil
  prop :identify, _Boolean, default: false

  def view_template
    div(class: "panel-body rss-box-details") do
      render_what_section
      render_where_section
      render_when_who_section
      render_source_credit
    end
  end

  private

  def render_what_section
    h_style = @data[:image] ? "h5" : "h3"

    div(class: "rss-what") do
      h5(class: class_names(%w[mt-0 rss-heading], h_style)) do
        a(href: url_for(@data[:what].show_link_args)) do
          render_title
        end
        render_id_badge(@data[:what])
      end

      render_identify_ui if @identify
    end
  end

  def render_title
    fragment("box_title") do
      render Components::MatrixBox::Title.new(
        id: @data[:id],
        name: @data[:name],
        type: @data[:type]
      )
    end
  end

  def render_id_badge(obj)
    whitespace
    show_title_id_badge(obj, "rss-id")
  end

  def render_identify_ui
    return unless @data[:type] == :observation && @data[:consensus]

    consensus = @data[:consensus]
    obs = @data[:what]

    if (obs.name_id != 1) && (naming = consensus.consensus_naming)
      div(
        class: "vote-select-container mb-3",
        data: { vote_cache: obs.vote_cache }
      ) do
        naming_vote_form(naming, nil, context: "matrix_box")
      end
    else
      propose_naming_link(
        obs.id,
        btn_class: "btn btn-default d-inline-block mb-3",
        context: "matrix_box"
      )
    end
  end

  def render_where_section
    return unless @data[:where]

    div(class: "rss-where") do
      small do
        location_link(@data[:where], @data[:location])
      end
    end
  end

  def render_when_who_section
    return if @data[:when].blank?

    div(class: "rss-what") do
      small(class: "nowrap-ellipsis") do
        span(class: "rss-when") { @data[:when] }
        plain(": ")
        user_link(@data[:who], nil, class: "rss-who")
      end
    end
  end

  def render_source_credit
    target = @data[:what]
    return unless target.respond_to?(:source_credit) &&
                  target.source_noteworthy?

    div(class: "small mt-3") do
      div(class: "source-credit") do
        small do
          raw(target.source_credit.tpl)
        end
      end
    end
  end
end
