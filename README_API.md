Mushroom Observer API
=====================

Last revised 2016 Aug 7.

Overview
--------

Mushroom Observer supports a simple API based on sending GET, POST, PUT and
DELETE requests to URLs of the form:

* <http://mushroomobserver.org/api/database_table>

GET requests are read-only and do not require authentication.  POST (create),
PUT (update) and DELETE (destroy) requests require authentication via an API
key (see below).

Responses can be requested in either XML (default) or JSON. You can either
set the appropriate HTTP request header, or you can request it explicitly with
a parameter (see below).

GET Requests
------------

All GET queries accept a bunch of parameters allowing you to restrict the
results to a specified subset.  For example, you can filter observations by
name, location, date, user, confidence, presence of images, comment text, etc.
Combinations are of course welcome.

In addition to these filter parameters two special pseudoparameters are
accepted:

* help=1 -- Resturn a list of accepted parameters.
* detail=none -- Return only record ids (default).
* detail=low -- Return some basic data with each record.
* detail=high -- Return a great deal of data with each record.
* format=xml -- Return XML response.
* format=json -- Return JSON response.

Note that the result will be paginated for detailed responses.  High detail
responses in particular are intended for very small data sets.  For example,
you might request a list of ids matching a set of parameters, then one by one
request full detail records for each of the matching records.

It is easy to play with this aspect of the API in a browser.  Try the following
queries, for example:

* GET <http://mushroomobserver.org/api/observations?children_of=Tulostoma>
* GET <http://mushroomobserver.org/api/observations?locations=Delaware&date=6>
* GET <http://mushroomobserver.org/api/observations?help=1>

These return the ids of, respectively, (1) all observations of the genus
Tulostoma, (2) all observations from Delaware posted in June (any year), and
(3) a list of accepted query parameters.

POST Requests
-------------

Only four tables accept POST requests presently: observations, images, users
and api_keys (see below).  Include data for the new record in parameters.
Example:

* POST <http://mushroomobserver.org/api/observations?api_key=xxx&name=Agaricus&location=USA,+California,+Pasadena&date=2016-08-06&notes=growing+in+lawn>

The response will include the id of the new record.

Attach the image as POST data or URL.  See script/test_api for an example of how
to attach an image in the POST data.

PUT Requests
------------

None are tested at the moment.  In principle one would structure the query the
same as for GET requests, including "set_xxx" parameters to tell MO how to
modify all of the matching records.  For example, this would be a way to change
the location of a set of your observations:

* PUT <http://mushroomobserver.org/api/observations?api_key=xxx&user=jason&id=12300-12400&set_location=USA,+California,+Pasadena>

DELETE Requests
---------------

None are tested at the moment.  In principle one would structure the query the
same as for GET requests.  MO will destroy all matching records.  For example,
this should delete all your observations from a given location:

* DELETE <http://mushroomobserver.org/api/observations?api_key=xxx&user=jason&locations=Madison+Heights>

API Keys
-------------

Authorization is currently done using an API key.  Just include your API key in
any POST, PUT and DELETE requests.  An API key belongs uniquely to a single
user, so MO will know who you are.

The easiest way for an individual user to obtain an API key is to create one
directly via the website:

* <http://mushroomobserver.org/account/api_keys>

For convenience, apps may also create a key on behalf of a user using a POST
request:

* POST <http://mushroomobserver.org/api/api_keys?api_key=xxx&user=xxx>

In this case, the app creator must create a special API key for that app.  This
is the key that will be used in the request above to create a new API key for
another user.  The user will then receive an email asking them to confirm that
it's okay for your app to post observations and images in their name.  The app
will then use the user's new API key for all subsequent POST requests.  The app
will be responsible for remembering and keeping secure each user's API key.

Apparently, it should also be possible for an app to create an account for a
new user, too.  I don't remember writing this, but it apparently has extensive
unit tests to guarantee that it works correctly(!)  Presumably the new user
will have to verify their email address like usual before the app can create an
API key for them and post observations.

All of this is still very unsecure.  If anyone gets a hold of a user's API key
they can readily POST things in their name.  Various users have suggested we
look into using more secure authorization methods such as OAuth and https.
Anyone interested in hooking us up is welcome to contribute.  We'd be happy to
help.

Database Tables
---------------

In principle, each of the major database tables has an entry point in the API.
However, only a handful of requests are officially tested:

* comments (GET)
* images (GET and POST)
* locations (GET)
* names (GET)
* observations (GET and POST)
* projects (GET)
* species_lists (GET)
* users (GET and POST)

Use the special "help=1" parameter to request a set of parameters supported for
each table.  Detailed documentation doesn't exist; we're relying on things
being simplistic enough to be more or less self-explanatory.  Note that it is
safe to mess around with strange parameters and see what they do.  Note that
XML responses include a copy of the SQL query used.  This can be a very
effective way of discovering exactly how unfamiliar parameters work.  Here's
the SQL query from one of the examples above:

    SELECT DISTINCT observations.id
    FROM `observations`
    WHERE MONTH(observations.when) >= 6 AND MONTH(observations.when) <= 6
    AND (observations.location_id IN (694,...,14040) OR observations.where LIKE '%Delaware%')
    ORDER BY observations.id ASC

See also the database diagram here:

* <https://github.com/MushroomObserver/mushroom-observer/blob/master/DATA_STRUCTURE.gif>

and the database schema here:

* <https://github.com/MushroomObserver/mushroom-observer/blob/master/db/schema.rb>
