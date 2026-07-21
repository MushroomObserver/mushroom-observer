# frozen_string_literal: true

require("test_helper")

class SymbolExtensionsTest < UnitTestCase
  def test_localize_postprocessing
    Symbol.raise_errors
    assert_equal("",             Symbol.test_localize(""))
    assert_equal("blah",         Symbol.test_localize("blah"))
    assert_equal("one\n\ntwo",   Symbol.test_localize('one\n\ntwo'))
    assert_equal("bob",          Symbol.test_localize("[user]", user: "bob"))
    assert_equal(
      "bob and fred",
      Symbol.test_localize("[bob] and [fred]", bob: "bob", fred: "fred")
    )
    assert_equal("user",
                 Symbol.test_localize("[:user]"))
    assert_equal("Show Name",
                 Symbol.test_localize("[:show_object(type=:name)]"))
    assert_equal("Show Str",
                 Symbol.test_localize("[:show_object(type='str')]"))
    assert_equal("Show Str",
                 Symbol.test_localize('[:show_object(type="str")]'))
    assert_equal("Show 1",
                 Symbol.test_localize("[:show_object(type=1)]"))
    assert_equal("Show 12.34",
                 Symbol.test_localize("[:show_object(type=12.34)]"))
    assert_equal("Show -0.23",
                 Symbol.test_localize("[:show_object(type=-0.23)]"))
    assert_equal("Show Xxx",
                 Symbol.test_localize("[:show_object(type=id)]", id: "xxx"))
    assert_equal("Show Image",
                 Symbol.test_localize("[:show_object(type=id)]", id: :image))
    assert_equal(
      "Show < ! >",
      Symbol.test_localize('[:show_object(type="< ! >",blah="ignore")]')
    )

    # Test capitalization and number.
    assert_equal("name", :name.l)
    assert_equal("Name", :name.ti)
    assert_equal("observation list", :species_list.l)
    assert_equal("Observation List", :species_list.ti)
    assert_equal("observation list",
                 Symbol.test_localize("[type]", type: :species_list))
    assert_equal("Observation list",
                 Symbol.test_localize("[Type]", type: :species_list))
    assert_equal("Observation list",
                 Symbol.test_localize("[tYpE]", type: :species_list))
    assert_equal("Observation List",
                 Symbol.test_localize("[TYPE]", type: :species_list))
    assert_equal("Observation Lists",
                 Symbol.test_localize("[TYPES]", type: :species_list))
    assert_equal("observation list", Symbol.test_localize("[:species_list]"))
    assert_equal("Observation List",
                 Symbol.test_localize("[:species_list.ti]"))
    assert_equal("Observation list", Symbol.test_localize("[:Species_list]"))
    assert_equal("Observation list", Symbol.test_localize("[:sPeCiEs_lIsT]"))
  end

  # Symbol.titleize_localized is a pure function of I18n.locale -- it
  # never touches TranslationString/Language. But I18n.available_locales
  # is derived from whichever config/locales/*.yml files exist, which
  # `rails lang:update` generates only for locales with a Language row
  # in whatever DB it ran against. CI's test DB only has the 6
  # languages fixtures.yml defines, so I18n.with_locale(:pl) (etc.)
  # would raise I18n::InvalidLocale there even though the fixture set
  # has nothing to do with what this test is actually exercising.
  def test_titleize_localized_all_locales
    original_locales = I18n.available_locales
    I18n.available_locales = (original_locales + TI_TEST_STRINGS.keys).uniq

    assert_titleize_localized_word_capitalize_locales
    assert_titleize_localized_no_ops
    assert_titleize_localized_turkic
    assert_titleize_localized_sentence_case
  ensure
    I18n.available_locales = original_locales
  end

  # capitalize_each_word (the TI_WORD_CAPITALIZE_LOCALES path) leaves
  # a word with any uppercase letter past its first position untouched
  # instead of running it through .capitalize, which would downcase
  # everything after the first letter and destroy a real acronym the
  # lowercase tag already stores correctly -- confirmed against real
  # content across nearly every word-capitalize locale: fully-uppercase
  # acronyms ("API key" -> "Api Key", "ДНК" -> "Днк") and mixed-case
  # ones too ("IDs" -> "Ids"), before this fix. No acronym config
  # needed either way.
  def test_capitalize_each_word_preserves_acronyms
    assert_equal("API Key", Symbol.capitalize_each_word("API key"))
    assert_equal("IDs", Symbol.capitalize_each_word("IDs"))
    I18n.with_locale(:uk) do
      assert_equal("Ключ API", Symbol.capitalize_each_word("ключ API"))
    end
  end

  # TI_LOWERCASE_WORDS: small connector words stay lowercase even when
  # the rest of the phrase is capitalized, confirmed empirically
  # (#4844 deviation audit) -- but only outside the first-word
  # position.
  def test_capitalize_each_word_lowercase_exceptions
    I18n.with_locale(:en) do
      assert_equal("Created at", Symbol.capitalize_each_word("created at"))
      assert_equal("Entered by", Symbol.capitalize_each_word("entered by"))
      assert_equal("Group or Clade",
                   Symbol.capitalize_each_word("group or clade"))
      assert_equal("Widget with Gadget",
                   Symbol.capitalize_each_word("widget with gadget"))
      assert_equal("Widget and Gadget",
                   Symbol.capitalize_each_word("widget and gadget"))
    end
    I18n.with_locale(:es) do
      assert_equal("Grupo de Admin",
                   Symbol.capitalize_each_word("grupo de admin"))
      # First word is never exempted, even if it matches the list.
      assert_equal("De Nuevo", Symbol.capitalize_each_word("de nuevo"))
    end
    I18n.with_locale(:pt) do
      assert_equal("Grupo ou Clado",
                   Symbol.capitalize_each_word("grupo ou clado"))
    end
    I18n.with_locale(:uk) do
      assert_equal("Внесення в Каталог",
                   Symbol.capitalize_each_word("внесення в каталог"))
    end
  end

  def test_hello
    assert_equal("Hello world", :hello.t)
  end

  def test_the_birds_flew_by
    assert_equal("The birds flew by", :they_flew_by.t(they: "birds"))
  end

  def test_birds_fly
    assert_equal("Birds fly", :they_fly.t(they: "birds"))
  end

  def test_quotes
    assert_equal("This has &#8220;quotes&#8221;", :quote_test.t)
  end

  def test_quote_birds
    assert_equal("This has &#8220;Birds&#8221;", :quote_them.t(them: "birds"))
  end

  def test_Yep # rubocop:disable Naming/MethodName
    assert_equal("Yes", :yep.ti)
  end

  def test_yep
    assert_equal("yes", :yep.t)
  end

  def test_Nope # rubocop:disable Naming/MethodName
    assert_equal("No", :nope.ti)
  end

  def test_nope
    assert_equal("no", :nope.t)
  end

  def test_with_newlines
    assert_equal("This<br />\nhas<br />\nnewlines", :with_newlines.t)
  end

  def test_with_a_link
    assert_equal("<a href=\"https://mushroomobserver.org\">See this link</a>",
                 :with_a_link.t)
  end

  def test_hello_has_translation
    assert(:hello.has_translation?)
  end

  def test_Hello_has_translation # rubocop:disable Naming/MethodName
    assert(:Hello.has_translation?)
  end

  def test_no_translation
    assert_not(:no_translation.has_translation?)
  end

  def test_upcase_first
    assert_equal(:A, :a.upcase_first)
    assert_equal(:AB, :aB.upcase_first)
    assert_equal(:Abc, :abc.upcase_first)
  end

  def test_never_add
    assert_equal("[:never_add]", :never_add.t)
    assert_equal("[:never_add(an_arg=:arg)]", :never_add.t(an_arg: :arg))
    Symbol.missing_tags = []
  end

  # capitalize_first_letter_only (the plain sentence-case path) must
  # NOT downcase the rest of the string the way String#capitalize
  # does -- that was destroying embedded acronyms the lowercase tag
  # already stores correctly whenever they aren't the very first word
  # (confirmed against real content: Polish's icn_id tag stores
  # "ICN Identyfikator"; plain .capitalize flattened it to
  # "Icn identyfikator").
  def test_capitalize_first_letter_only_preserves_embedded_casing
    assert_equal("Lista gatunków",
                 Symbol.capitalize_first_letter_only("lista gatunków"))
    assert_equal("ICN Identyfikator",
                 Symbol.capitalize_first_letter_only("ICN Identyfikator"))
    assert_equal("", Symbol.capitalize_first_letter_only(""))
  end

  # Real translated content for :species_list.l and :rss_logs.l (both
  # real multi-word `.ti` inputs in production -- see
  # filter_caption.rb#type_tags_to_label for :rss_logs.ti) across
  # every one of MO's 16 production locales, not just the 6 the test
  # fixtures carry. Values pulled directly from the production
  # checkpoint so the assertions exercise real translator output, not
  # a made-up placeholder string.
  TI_TEST_STRINGS = {
    en: { species_list: "observation list", rss_logs: "activity logs" },
    ar: { species_list: "قائمة الأنواع", rss_logs: "سجلات النشاط" },
    fa: { species_list: "فهرست گونه ها",
          rss_logs: "سیاهههای مربوط به فعالیت" },
    zh: { species_list: "观察记录列表", rss_logs: "活动记录" },
    jp: { species_list: "種名一覧", rss_logs: "履歴" },
    # German nouns are capitalized wherever they fall in the phrase --
    # "Änderungen" (Changes) here is correct mid-phrase, not a typo.
    # `.capitalize` would downcase it to "änderungen", which is wrong.
    de: { species_list: "Artenliste",
          rss_logs: "Logbuchen der neuen Änderungen" },
    tr: { species_list: "tür listesi", rss_logs: "etkinlik kayıtları",
          index: "indeks" },
    be: { species_list: "спіс відаў", rss_logs: "часопісы дзейнасці" },
    el: { species_list: "κατάλογος Ειδών", rss_logs: "αρχεία Μεταβολών" },
    es: { species_list: "lista de observaciones",
          rss_logs: "registros de actividad" },
    fr: { species_list: "liste d'espèces", rss_logs: "journals d'activité" },
    it: { species_list: "elenco delle specie",
          rss_logs: "registri d'attività" },
    pl: { species_list: "lista gatunków", rss_logs: "dzienniki aktywności" },
    pt: { species_list: "lista de espécies",
          rss_logs: "registos de atividade" },
    ru: { species_list: "список видов", rss_logs: "логи активности" },
    uk: { species_list: "список видів", rss_logs: "журнали активності" }
  }.freeze

  TI_WORD_CAPITALIZE_EXPECTED = {
    en: { species_list: "Observation List", rss_logs: "Activity Logs" },
    es: { species_list: "Lista de Observaciones",
          rss_logs: "Registros de Actividad" },
    pt: { species_list: "Lista de Espécies",
          rss_logs: "Registos de Atividade" },
    el: { species_list: "Κατάλογος Ειδών", rss_logs: "Αρχεία Μεταβολών" },
    uk: { species_list: "Список Видів", rss_logs: "Журнали Активності" },
    be: { species_list: "Спіс Відаў", rss_logs: "Часопісы Дзейнасці" }
  }.freeze

  private

  # capitalize_each_word does the per-word capitalization by hand for
  # every locale here, including English -- see TI_WORD_CAPITALIZE_LOCALES.
  def assert_titleize_localized_word_capitalize_locales
    Symbol::TI_WORD_CAPITALIZE_LOCALES.each do |locale|
      strs = TI_TEST_STRINGS.fetch(locale)
      expected = TI_WORD_CAPITALIZE_EXPECTED.fetch(locale)
      I18n.with_locale(locale) do
        assert_equal(expected[:species_list],
                     Symbol.titleize_localized(strs[:species_list]),
                     "Expected per-word capitalize for locale #{locale}")
        assert_equal(expected[:rss_logs],
                     Symbol.titleize_localized(strs[:rss_logs]),
                     "Expected per-word capitalize for locale #{locale}")
      end
    end
  end

  # No letter-casing concept at all (ar/fa/zh/jp), or (de) the base
  # translation is already correctly capitalized -- .capitalize would
  # be destructive either way, so `Symbol::TI_NO_OP_LOCALES` is a
  # pure pass-through.
  def assert_titleize_localized_no_ops
    Symbol::TI_NO_OP_LOCALES.each do |locale|
      strs = TI_TEST_STRINGS.fetch(locale)
      I18n.with_locale(locale) do
        assert_equal(strs[:species_list],
                     Symbol.titleize_localized(strs[:species_list]),
                     "Expected no-op for locale #{locale}")
        assert_equal(strs[:rss_logs],
                     Symbol.titleize_localized(strs[:rss_logs]),
                     "Expected no-op for locale #{locale}")
      end
    end
  end

  # Turkish's i/I case-mapping is locale-specific (dotted/dotless);
  # "indeks" (:index.l) shows the distinction from plain .capitalize.
  def assert_titleize_localized_turkic
    strs = TI_TEST_STRINGS[:tr]
    Symbol::TI_TURKIC_LOCALES.each do |locale|
      I18n.with_locale(locale) do
        assert_equal("Tür Listesi",
                     Symbol.titleize_localized(strs[:species_list]))
        assert_equal("İndeks", Symbol.titleize_localized(strs[:index]))
      end
    end
  end

  # Every other locale MO supports: sentence-case (capitalize only the
  # first letter). Matches the "Listes d'espèces" example in #4844 --
  # only the phrase's first letter is capitalized, so an apostrophe-led
  # word later in the phrase (French/Italian elision) is untouched,
  # sidestepping .titleize's English-contraction assumption entirely.
  def assert_titleize_localized_sentence_case
    other_locales = TI_TEST_STRINGS.keys -
                    (Symbol::TI_NO_OP_LOCALES + Symbol::TI_TURKIC_LOCALES +
                     Symbol::TI_WORD_CAPITALIZE_LOCALES)
    other_locales.each do |locale|
      strs = TI_TEST_STRINGS.fetch(locale)
      I18n.with_locale(locale) do
        assert_equal(Symbol.capitalize_first_letter_only(strs[:species_list]),
                     Symbol.titleize_localized(strs[:species_list]),
                     "Expected sentence-case for locale #{locale}")
        assert_equal(Symbol.capitalize_first_letter_only(strs[:rss_logs]),
                     Symbol.titleize_localized(strs[:rss_logs]),
                     "Expected sentence-case for locale #{locale}")
      end
    end
  end
end
