Last Revised: Feb 18, 2025

# MushroomObserver

<!-- Most links are defined here for DRYness and consistency -->
[Intro]: https://mushroomobserver.org/info/intro
[Ruby Documentation]: https://www.ruby-doc.org/core/
[Ruby Quick Ref]: https://www.zenspider.com/ruby/quickref.html
[Rails Documentation]: https://api.rubyonrails.org/
[MVC Architecture]: https://en.wikipedia.org/wiki/Model-view-controller
[RuboCop]: https://rubocop.org/
[SimpleCov]: https://github.com/simplecov-ruby/simplecov
[Stimulus]: https://stimulus.hotwired.dev/
[Turbo]: https://turbo.hotwired.dev/

The following is an overview of the code for the Mushroom Observer website for
prospective developers.  See [Intro][Intro] for an
introduction to the website itself.

## Ruby on Rails

MO is written using Ruby on Rails, or simply Rails.  This is just a set of
three heavily interrelated Ruby packages: ActionController, ActionView, and
ActiveRecord.  The basic architecture is model, view, controller -- that is,
the webserver receives a request, passes it to the appropriate controller,
which decides what actions to take and gathers whatever data is needed (from
the "models"), then renders the result via HTML templates (the "views").

Rails applications run in one of three different modes: development, production
and test.  Each has its own entirely separate database (named appropriately
`observer_development`, `observer_production` and `observer_test`).

**development:**
  Server automatically reloads any code that has been changed.  (Only modules that
  have been required using `require_dependency`.)  Doesn't cache data the same
  way as the production server does.

**production:**
  Need to restart the server whenever you change any code.  Some things are
  cached differently than in development, so if you see different behavior on
  the production server, start here: you might just need to reload an object.

**test:**
  Used by the testing framework.  All changes are thrown away between each
  test.  And various Rails inner modules are swapped out with test mock-ups.

- [Ruby Documentation][Ruby Documentation]
- [Ruby Quick Ref][Ruby Quick Ref]
- [Rails Documentation][Rails Documentation]
- [MVC Architecture][MVC Architecture]

## Database

MO uses MySQL.  The current schema is `db/schema.rb`.  All modifications
of the structure, such as adding tables or changing existing columns, are
handled using the handy migrations in `db/migrate`.

```
  rails db:migrate                          # Create or update database.
  rails db:rollback                         # Rollback last migration run.
  rails db:migrate VERSION=YYYYMMDDHHMMSS   # Rollback to previous version.
```

## Important Models

Database access is all done via subclasses of ApplicationRecord
("models").  Each instance of a model represents a single row in the
corresponding database table.  Look for observations in the class
Observation, user/account settings in User, taxonomy in Name and
Synonym, and so on.  These are all found in `app/models`.  Here
are the major ones:

- User::        Name, email, password, prefs, etc.
- Observation:: Where, when, what, notes, etc.
- Image::       Images mostly of mushrooms, but also mugshots, etc.
- Name::        Scientific name bundled with notes, citation, etc.
- Location::    Lat/long/elev, notes, etc.
- Project::     Collection of bservations, names, locations
- SpeciesList:: Set of Observation's (*_not_* Name's).

See the code for a complete list of models and classes used by the
system to support our data model.

## How to Accomplish Typical Developer Tasks

### Writing Tests

Automated testing is a critical part of developing code for Mushroom
Observer.  We currently have over 90% test coverage across our codebase
and our continuous integration system will not approve a PR if it causes a
drop in our percent of coverage.  Developers should be familiar with the
[SimpleCov] tool for generating coverage reports.

#### Running Tests

Tests run in parallel by default with SimpleCov coverage reporting enabled:

```bash
rails test                      # Run all tests in parallel with coverage
rails test path/to/test.rb      # Run specific test with coverage
```

Coverage reports are automatically generated at `coverage/index.html` and can be
viewed in your browser. SimpleCov now supports parallel test execution, so there
is no performance penalty for coverage reporting.

### Live Website Issues

#### Functional Bugs

Functional bugs in the live website should be documented with GitHub
issues (<https://github.com/MushroomObserver/mushroom-observer/issues>).
The most important thing is to document the steps to reproduce the
issue and any known workaround.  This will help others understand the
problem and ensure that any proposed fix solves the original issue.

When working on bug, creating an automated test for the issue is
strongly encouraged.  Ideally this is the first step in addressing the
issue, but we recognize that often digging directly into the code can
be important to understanding the root cause of the problem.  In
addition, for urgent issues it may be important to find a fix first
and write the tests after.  However, the work should not be considered
done until there are automated tests in place that ensure the problem
does not resurface at some point in the future and that any needed code is
fully covered.

In general tests should be run against the target branch (typically
`main`) to ensure that they fail without the proposed changes.  This
is particularly important for functional bugs to ensure that the
original bug is well characterized by the test.

#### Performance Issues

There are two common sources of website performance issues - outside
entities abuse the website ("attacks") and performance issues in our
code base ("performance bugs").

To analyze attacks, you need to have access to the webserver logs.  We
have a collection of tools that we use for parsing logs to detect
issues and to block "bad actors" that are impacting the website
performance.  Please send email to <webmaster@mushroomobserver.org> if
you believe that there is currently a performance issue that may be
the result of an attack.

For performance bugs, the most common source of such issues are
excessive database queries.  These are often called "N+1" issues.
These issues can be spotted by reviewing the number of database
queries that get executed when a page gets rendered.  In general, the
expectation is that any given page should perform less than 50
database queries.  If more queries than that are being generated, you
should review the queries and look for any repeated query patterns.
Typically these can be addressed by finding some part of the code that
is making database queries inside a loop.  Such queries should be
moved outside the loop and setup so it extracts the data for all the
iterations in a single query.  This data should then be made available
inside the loop where it can be quickly accessed from memory rather
than requiring a full round trip to the database for each iteration.

### New Features

For new features, it is often best to start with designing the user
interface (UI).

#### Simple Features

If the feature is embedded in an existing page, then you can often
then fake the UI in the appropriate view and then build out the
functionality on the backend.

#### Features Requiring a New Model

If the feature requires new pages, then often there will be some new
database model associated with each such page.  If that's the case
then you will probably also want a new controller, a set of views, and
bunch of other stuff.  You can get started in this direction by using
the Rails scaffold generator.  E.g.,

`rails generate scaffold MyModel foo:string bar:integer`

This should create all the files neccesary for a very simple CRUD interface
for a new model.  While this can get you started on your new feature
very quickly, it has some caveats.  First, the default generators do
not follow our coding conventions.  You can address some of this by
running [RuboCop] on all the new Ruby files.  Using the -A option will
autocorrect most if not all of the violations.  However, note that
[RuboCop] does not work on our view files (ERB files).  The most common
violations of our coding standards that happen in such ERB files are
missing parentheses and single quotes rather than double quotes.

Another common issue with using rails generators in our code base is
that the result is kind of clunky, requiring separate page loads for
each form or button interaction.  The preferred approach for these
types of interactions is to use [Turbo] and [Stimulus].

A common example where [Turbo] in particular can improve the user
experience is index pages for new models.  The New, Edit, and
Delete actions can all be handled using buttons that are [Turbo]
enabled with New and Edit leveraging [Turbo] to manage the object
form through a modal.

Here are the steps for implementing this:

1) Add a place for the New, Edit, and Delete widgets.  This may
involve switching to a table layout.  For example see:
`app/views/controllers/projects/locations/index.html.erb`

2) Create partial for the widgets.  Note that it is important
to have a unique id for each set of widgets on the page since
that's what [Turbo] will use to update the page.  For example see:
`app/views/controllers/projects/_aliases.html.erb`
and specifically the line:

```erb
<%= tag.div(id: "target_project_alias_#{target.id}") do %>
```

3) The links for the widgets that want to render the form as a model
should call `modal_link_to` which again cares about the value of the
HTML id.  For example see: `ProjectsHelper#edit_project_alias_link`.
Note that this method also uses the MO concept of "tabs" to describe
page links.

4) The real "[Turbo]-ness" of this approach happens in the relevant
controller.  See the use of `turbo_stream` in:
`app/controllers/projects/aliases_controller.rb` These actions use the
shared partials `modal_form` and `modal_form_reload` as well as an
updated partial to present the form as a modal and to update the index
page using [Turbo].  For the modal form to work, the ERB for the form
should be named just `_form.erb` and not `_form.html.erb` since it may
be rendered either as regular HTML or as a [Turbo] stream.  An example
update partial is:
`app/views/controllers/projects/aliases/_target_update.erb` This is
where the unique id in step 2 is important.  Finally note the calls to
`close_modal` and `remove` at the bottom of this file.  These are
required to hide the modal after the form data has been processed.
