# frozen_string_literal: true

class Components::IndexPaginationNav < Components::Base
  include Phlex::Slotable

  slot :sorter

  prop :pagination_data, _Nilable(PaginationData)
  prop :position, Symbol, default: -> { :top }
  prop :args, Hash, default: -> { {} }
  # These need to be passed from the helper which has access to request/params
  prop :request_url, String     # Full URL with query params for link generation
  prop :form_action_url, String # URL without query params for form actions
  prop :q_params, _Nilable(Hash)
  prop :letter_param, _Nilable(String)

  def view_template
    div(class: "pagination-#{@position} navbar-flex mb-2") do
      div(class: "d-flex") { render(sorter_slot) if sorter_slot? }
      div(class: "d-flex") do
        render_letter_pagination_nav
        render_number_pagination_nav
      end
    end
  end

  private

  def render_letter_pagination_nav
    return unless need_letter_pagination_links?

    args = @args.dup
    args[:params] = (args[:params] || {}).dup
    args[:params][@pagination_data.number_arg] = nil

    this_letter, letters = letter_pagination_pages

    nav(class: "paginate pagination_letters navbar-flex pl-4") do
      div(class: "navbar-text mx-0") { :by_letter.l }
      render_letter_input(this_letter, letters)
    end
  end

  def render_number_pagination_nav
    return unless @pagination_data && @pagination_data.num_pages > 1

    setup_letter_params
    arg = @pagination_data.number_arg
    this_page, prev_page, next_page, max_page = number_pagination_pages

    nav(class: "paginate pagination_numbers navbar-flex pl-4") do
      render_prev_page_link(prev_page, arg)
      render_page_label
      render_goto_page_input(this_page, max_page)
      render_max_page_link(max_page, arg)
      render_next_page_link(next_page, max_page, arg)
    end
  end

  def setup_letter_params
    params = @args[:params] ||= {}
    return unless @pagination_data.letter_arg && @pagination_data.letter

    params[@pagination_data.letter_arg] = @pagination_data.letter
  end

  def render_page_label
    div(class: "navbar-text mx-0 hidden-xs") { :PAGE.l }
  end

  def render_max_page_link(max_page, arg)
    max_url = pagination_link_url(max_page, arg)
    div(class: "navbar-text ml-0 mr-2 hidden-xs") { :of.l }
    div(class: "navbar-text mx-0") { a(href: max_url) { max_page.to_s } }
  end

  def number_pagination_pages
    max_page = @pagination_data.num_pages
    this_page = @pagination_data.number
    this_page = 1 if this_page < 1
    this_page = max_page if this_page > max_page
    prev_page = this_page - 1
    next_page = this_page + 1
    [this_page, prev_page, next_page, max_page]
  end

  def render_prev_page_link(prev_page, arg)
    disabled = prev_page < 1 ? "disabled opacity-0" : ""
    classes = class_names(
      %w[navbar-link btn btn-lg px-0 previous_page_link], disabled
    )
    url = pagination_link_url(prev_page, arg)
    a(href: url, class: classes) { link_icon(:prev, title: :PREV.t) }
  end

  def render_next_page_link(next_page, max, arg)
    disabled = next_page > max ? "disabled opacity-0" : ""
    classes = class_names(
      %w[navbar-link btn btn-lg px-0 next_page_link], disabled
    )
    url = pagination_link_url(next_page, arg)
    a(href: url, class: classes) { link_icon(:next, title: :NEXT.t) }
  end

  def pagination_link_url(page, arg)
    params = @args[:params] || {}
    params[arg] = page
    url = add_args_to_url(@request_url, params.merge(id: nil))
    if @args[:anchor]
      url.sub!(/#.*/, "")
      url += "##{@args[:anchor]}"
    end
    url
  end

  def render_goto_page_input(this_page, max_page)
    form(
      action: @form_action_url, method: :get,
      class: "navbar-form px-0 page_input",
      data: { controller: "page-input", page_input_max_value: max_page }
    ) do
      render_page_input_group(this_page, max_page)
      render_q_hidden_fields
      render_letter_hidden_field
    end
  end

  def render_page_input_group(this_page, max_page)
    div(class: "input-group page-input mx-2") do
      input(**page_input_attrs(this_page, max_page))
      render_goto_button
    end
  end

  def page_input_attrs(this_page, max_page)
    {
      type: :text, name: :page, value: this_page,
      class: "form-control text-right",
      size: max_page.digits.count,
      data: { page_input_target: "numberInput",
              action: "page-input#sanitizeNumber" }
    }
  end

  def render_goto_button
    span(class: "input-group-btn") do
      button(type: :submit, class: "btn btn-outline-default px-2") do
        link_icon(:goto, title: :GOTO.l)
      end
    end
  end

  def need_letter_pagination_links?
    return false unless @pagination_data

    @pagination_data.letter_arg &&
      (@pagination_data.letter ||
        @pagination_data.num_total > @pagination_data.num_per_page) &&
      @pagination_data.used_letters &&
      @pagination_data.used_letters.length > 1
  end

  def letter_pagination_pages
    letters = @pagination_data.used_letters
    this_letter = @pagination_data.letter || ""
    [this_letter, letters]
  end

  def render_letter_input(this_letter, used_letters)
    form(
      action: @form_action_url, method: :get,
      class: "navbar-form px-0 page_input",
      data: { controller: "page-input",
              page_input_letters_value: used_letters }
    ) do
      div(class: "input-group page-input ml-2") do
        input(
          type: :text, name: :letter, value: this_letter,
          class: "form-control text-right",
          size: 1, placeholder: "—",
          data: { page_input_target: "letterInput",
                  action: "page-input#sanitizeLetter" }
        )
        render_goto_button
      end
      render_q_hidden_fields
    end
  end

  def render_q_hidden_fields
    return unless @q_params

    query_string = Rack::Utils.build_nested_query({ q: @q_params })
    pairs = query_string.split(Rack::Utils::DEFAULT_SEP)
    pairs.each do |pair|
      key, value = pair.split("=", 2).map { |str| Rack::Utils.unescape(str) }
      input(type: :hidden, name: key, value: value)
    end
  end

  def render_letter_hidden_field
    input(
      type: :hidden, name: :letter, value: @letter_param,
      data: { page_input_target: "letterHiddenInput",
              action: "letterUpdated@window->page-input#syncLetter" }
    )
  end
end
