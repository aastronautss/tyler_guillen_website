---
title: Tracebin, Part 2
subtitle: "The Server: Storing and Querying Application Performance Data"
category: programming
summary: When the agent was done, we turned to the server that ingests performance data transmitted by agents. Here we encountered problems of scale, database design, and data engineering.
---

This is part 2 of the story of [Tracebin](https://traceb.in), our "bin"-style application performance monitoring solution. You can read part 1 [here](http://tylerguillen.com/blog/2017/05/01/tracebin-story-part-1/).

The server side of Tracebin is a Ruby on Rails application. The user clicks a button that generates a “bin,” which is identified by a randomly-generated token, and can be accessed via a special URL. The page returned at that URL displays the statistics that we’ve made available based on the data sent by the agent. Each chart is asynchronously loaded via a separate endpoint. Agents send all data to a single route, and the app organizes the data accordingly.

The server side of Tracebin presented several engineering challenges for us to account for. Here are a few ways in which such an application was unique with respect to a standard Rails app:

- The app as a whole is extremely write-heavy. For every read operation, there may be hundreds or  thousands of writes.
- Rather than loading specific records, our read operations are more oriented around aggregating over large sets of records.

Here, we’ll discuss the application and data architecture decisions we made, as well as other alternatives we may eventually consider.

## Writing Data
Most of our application’s activity involves the ingestion of large sets of data at a more-or-less constant rate. By default, the server receives data from each agent every minute. Data is received in a JSON array of object, with each object needing to be organized in the correct table.

How, then, should this data be organized? We have many decisions to make for this at nearly every level, from which database to which indexes we need to create. We’ll start from the very top and work our way down from there.

### SQL or Not?
Our service seems like the core target for many NoSQL databases, particularly MongoDB and Cassandra. They excel in write-heavy applications with predefined query paths, sacrificing flexibility for QPS. They are extremely performant, as long as you work with their constraints. Since interactions with our application are fairly constant (that is, user interaction is constrained and predictable), NoSQL stood as a fairly solid choice.

However, we decided to stick with SQL—namely, PostgreSQL—for the current iteration of our service for the following reasons. First, our current knowledge of SQL far exceeds that of other databases, so ended up being a little more time-efficient to wrangle with any of SQL’s shortcomings that might pop up than it would be to learn a new database.

The more interesting reasons involved a single concept: queryability. PostgreSQL’s robust set of features especially shines in this respect, with numerous datatype options and robust extensions ecosystem. With virtual tables, SQL provides us with a more intuitive mental model for understanding our datasets, and it allows us to conjure up data based on what we need. PostgreSQL itself also gives us a little more flexibility on how we choose to represent our data. This will prove especially useful later on in our exploration.

Here’s the big takeaway, which has been the main theme for the database decisions we’ve made throughout this process: we want to store the data in a way that lends it self to how we plan to query it. Not only do SQL databases provide us with several additional degrees of freedom for the kinds of queries we plan to make, but they, especially PostgreSQL, allow us to perform more complicated aggregate operations closer to the database than other solutions, at least with our current level of knowledge.

### The Schema Dilemma: How normalized are your tables?
With our current model, we have two basic entity types: transactions and events. They exist in a one-to-many relationship. Events can be subdivided into three or four categories, each with their own kinds of attributes. For example, database operations don’t have the same kinds of characteristics as controller actions. Therefore, we might imagine a schema in which we have separate tables for each event type.

{% include blog_image_narrow.html img="tracebin_db_schema_1.png" title="Nested event structure." %}

Missing from There are a few problems with this. First, while this schema provides a great deal of flexibility, it comes at a cost of performance, especially when we keep in mind how we plan to query this data. With this in mind, it helps to recognize what kind of data we want from these tables. Here’s an example of the output we’re expecting:

{% include blog_image_narrow.html img="tracebin_output_endpoints_index.png" title="Nested event structure." %}

In order to obtain data for a table like this in a single query, we would need to perform JOINs on four tables, which will seriously impact performance when our application is up and running. Furthermore, there are a lot of repeated columns between our three `Events` tables, which indicates that it might be wise to combine them.

At the other end of the normalization spectrum, we end up with a completely denormalized schema in which all event data is stored in the `Transactions` table. PostgreSQL’s JSON datatype makes this possible while keeping the relation sane.

{% include blog_image_narrow.html img="tracebin_db_schema_2.png" title="Nested event structure." %}

The `events` column stores an array of JSON objects, each of which contains all the data related for the event. With this, we end up with what is essentially a NoSQL datastore. We can’t perform direct JOINs and aggregates on that JSON column, which means the table we’re trying to obtain may be difficult. Thankfully, there are several functions in PostgreSQL that help us to convert JSON structures into virtual tables, which we do end up doing with some endpoints.

Now, we could’ve used MongoDB all along if we wanted to structure our data like this! This also isn’t really the best schema for the table we’re trying to create, so let’s normalize out all events into their own table:

{% include blog_image_narrow.html img="tracebin_db_schema_3.png" title="Nested event structure." %}

Here, we have columns for all the information common to each event type, and put the data unique to each event type in a JSON object. We also add a custom ENUM datatype to indicate the event’s type. This way, if we need to get information specific to a certain event, we just need to put that type in the `WHERE` clause of our query. Notice how we keep the `events` column in `Transactions`, giving us two representations of each event. We do this because, as we will see, some queries will be easier to perform on the JSON objects, while others will be much easier with the `Events` table.

We must accept some tradeoffs with this model, and we’ll discuss these in the next section.

### Data Interchange
Now that we have the first stages of our database schema, we need to account for how our data gets transmitted over the wire from the agent. For now, we’ve chosen JSON as our format to accomplish this.

Per above, all data gets sent in an array of JSON objects. Each object needs to tell the application where it needs to be stored, along with what needs to be stored. For transactions, we chose a format that looks essentially like the `Transactions` table illustrated above:

```javascript
{
  "type": "transaction",
  "data": {
    "type": "request_response",
    "name": "VideosController#show",

    "start": "2017-04-26 10:09:43 -0400",
    "stop": "2017-04-26 10:09:43 -0400",
    "duration": 7.5680000000000005,
    "events": [ {}, {}, {} ]
  }
}
```

One consideration to make when choosing how our data should be transmitted is computation location and strategy. To understand this challenge, let’s go back to our mantra: data must be persisted to reflect how it will be queried. The raw data collected by our agent comes in pieces that aren’t extremely useful for presenting our data. For instance, `name` and `duration` must be computed, since they aren’t present. Any computed data like this must be computed on either the side of the agent or the server. Since we don’t want to impact the host application’s performance with extra computational tasks, we let the server handle most tasks, with the exception of computing `duration` and `type`, both of which can be completed in synchronously in a reasonable amount of time.

One thing do on the server side is organize the “events” JSON array by event type, spanning across four categories: endpoint, database, view, and other. This allows us to more easily generate runtime profiles like the one below:

{% include blog_image_narrow.html img="tracebin_output_endpoints_show.png" title="Nested event structure." %}

As we mentioned in the previous section, we also iterate through the `events` array to store individual records for each event associated with a transaction. All this data processing happens asynchronously with a background job engine (at the time of writing, we’re using Sidekiq), so that the agent isn’t stuck waiting for the server to finish persisting all of the event data.

Our goal here is to do all the computation ahead of time so that we can pull the data as directly as possible when we go to aggregate it. However, this is where we run into a bit of a problem. The more computation we do ahead of time, the longer it takes for us to process incoming payloads. We therefore want to be conscious of the amount of time this takes, since we don’t want it to exceed the frequency at which we receive payloads, since we will never be able to process every payload, and we’ll very quickly run out of memory. As it turns out, there is a considerable amount of overhead involved with saving individual events in their own table (per the strategy we discussed in the previous section), so this may not be the best possible strategy as our application grows.

One way to curb this is to leave enough “breadcrumbs” in our data interchange so that the server knows exactly where and how to store it, effectively transforming most O(n) logic into O(1) logic. For instance, since we’re organizing each bit of data by type, we need to make sure the server knows which type it right off the bat.

What we get in the end is a structure like this:

```javascript
{
  "identifier": "some_identifier",
  "params": {
    // This is where the object's actual data goes.
    "nested_objects": [
    {
      "identifier": "some_other_identifier",
      "params": {
      // These are the nested object attributes
      }
    },
    // More objects
    ]
  }
}
```

The `identifier` key (or equivalent) serves as a way to tell the server where it will be storing the data. Any nested objects follow this same pattern. What we get is a pipeline of data that makes it fast and easy for the application to know where to put the data.

One interesting quirk of Rails (and ActiveRecord in particular) is that there is no way to create multiple records with a single query right out of the box. This is a bit of a performance problem, especially with our process of ingesting agent payloads in mind. In our current model, we create event records for each transaction. This is a major bottleneck for our ingestion process, especially if it means creating individual ActiveRecord objects and and saving them to the database one by one. Luckily, there exists a gem called `activerecord-import` in active development that optimizes this process, allowing us to save multiple records in a single query. This reduces the amount of time it takes to persist an entire payload by about an order of magnitude. We can make this even faster by curtailing ActiveRecord validations, which is something we are currently experimenting with.

## Reading Data
Now that we’ve found an efficient way to persist our agent’s data, we need to find out a way to generate datasets for the charts in our UI. For this post, we’ll focus on two charts: the “Endpoints” table and the “endpoint sample profile” waterfall graph.

{% include blog_image_narrow.html img="tracebin_output_endpoints_index_and_show.png" title="Nested event structure." %}

We’re using two charting libraries for these charts: Datatables.net and the Google visualization library (now known as Google Charts). We chose them among the countless other charting libraries because they’re both flexible and take similar data structures as input. For each, we need an array of arrays, the elements of whom closely reflect the output. For Datatables (which we use for the Endpoints table), we just need to send data straight across to fill in the rows on the table. For Google Charts (which we use for the waterfall chart), the rows in the dataset reflect the size and positions of their respective bars.

#### Building Queries

Let's focus for a moment on the first table in the above screenshot, and explore how we can come to build the data for it. Here's an example of what the input for our endpoints table should look like--what our front end should receive from the server:

```javascript
// Columns: Endpoint, Hits, Median Response, Slow Response, % App, % SQL, % View, % Other
[
  ["VideosController#index", 14, 106.83, 157.74, 5.1, 6.08, 88.82, 0],
  ["PagesController#front", 13, 3.48, 7.23, 83.65, 16.35, 0, 0],
  ["UsersController#show", 10, 138.55, 260.27, 4.38, 13.74, 81.88, 0],
  ["CategoriesController#show", 9, 110.68, 246.13, 5.2, 3.18, 91.62, 0],
  ["VideosController#show", 9, 218.77, 624.61, 8.19, 7.95, 44.17, 39.7],
  ["FollowingsController#index", 7, 119.62, 146.27, 6.01, 10.14, 83.85, 0]
]
```

This array-of-arrays data structure lends itself to fairly easily pulling data straight from an SQL query’s output, allowing us to delegate most of the heavy computational lifting to the database engine, rather than the slower application layer.

To illustrate, let's see how to get each column for the endpoints table. The first four are fairly simple since, per the schema we illustrated above, we can pull those values straight from the the columns in the database.

```sql
SELECT
  name AS endpoint,
  count(*) AS hits,
  quantile(duration, 0.5) AS median_duration,
  quantile(duration, 0.95) AS ninety_fith_percentile_duration
FROM transactions
WHERE
  app_bin_id = #{ActiveRecord::Base.sanitize @app_bin_id} AND
  type = 'request_response' AND
  start > (current_timestamp - interval '1 day')
GROUP BY endpoint
ORDER BY hits DESC;
```

`quantile` comes from an extension, which allows us to quickly compute the percentile of a given column. The `WHERE` clause identifies the transactions by the bin in question, type (we want `'request_response'`, as opposed to `'background_job'`), and time interval (since our app only shows 24 hours of data).

The "% App", etc. columns are a little more tricky, and it might be useful to understand what they represent. For a web app, it's useful to know how much of a transaction is spent in each layer of the application. For example, we might spend just a little bit of time in the application itself, while the majority of time is spent rendering the view. These percentages will help us to show these characteristics at a glance.

Pulling them directly from the database might be difficult, but we can instead compute averages in a query, and then compute the percentages on the application layer. Before the JSON object for a transaction's events is persisted, we do a little bit of organizing by type so that we don't have to iterate through the events at query time.

```javascript
// Before:

{ // A Transaction object
  "Name": "VideosController#show",
  // Other transaction data...
  "Events": [
    {
      "type": "sql",
      "duration": 1.23,
      // Other event data...
    },
    {
      "type": "controller_action",
      "duration": 85.23,
      // Other event data
    },
    // etc...
  ]
}

// After:

{ // A Transaction object
  "Name": "VideosController#show",
  // Other transaction data...
  "Events": {
    "sql": [
      {}, {} // SQL events
    ],
    "controller_action": [
      {}, {} // Controller-action/Endpoint events
    ],
    // etc...
  }
}
```

Because of this, we can just run `events->'sql'` in our query if we want all of the SQL events, and so on. We probably didn't choose the best name for this key, since this is where all database queries would go, including NoSQL queries, but we can definitely change it later on.

Let's think about this: we want the total duration for all SQL, View, etc. events for each endpoint. We then want to average them out so we can compute their percentages. Let's first sum up the durations for a single transaction's SQL events:

```sql
SELECT sum(duration)
FROM jsonb_to_recordset(events->'sql') AS x(duration NUMERIC)
```

We can use PostgreSQL's `jsonb_to_recordset` function (we're using a JSONB datatype, since it's much faster to query, and we can add indexes to values nested within it), which allows us to pull a JSON object's key/value pairs as a virtual table, with the keys represented as the columns. Since we're only interested in the duration, we can simply pull that value, and then sum up the rows.

We then need to average those values over our entire dataset, so let's add it to our query.

```sql
SELECT
  name AS endpoint,
  count(*) AS hits,
  quantile(duration, 0.5) AS median_duration,
  quantile(duration, 0.95) AS ninety_fith_percentile_duration,
  -- Here's the subquery from above
  avg((
    SELECT sum(duration)
    FROM jsonb_to_recordset(events->'sql') AS x(duration NUMERIC)
  )) AS avg_time_in_sql
FROM transactions
WHERE
  app_bin_id = #{ActiveRecord::Base.sanitize @app_bin_id} AND
  type = 'request_response' AND
  start > (current_timestamp - interval '1 day')
GROUP BY endpoint
ORDER BY hits DESC;
```

Since that subquery returns a single value for each record, we can directly perform an aggregate on it. There is one problem here, though. Not all records necessarily have SQL events (thus our subquery will return `NULL` for them), and an aggregate function skips those rows. We therefore only get the average value for the transactions in which SQL events do occur. While this seems like something we may want, it will lead to problems when we go to compute the percentages. Say, for instance, an endpoint performs an SQL query only once every 100 executions. For the non-SQL executions, the duration of the transaction is 50ms, and for the executions with the SQL query, it takes 500ms. With our current query, the average time in SQL will be 450ms, while the average time in the App layer (since the app layer is computed with each execution, SQL or no) will be closer to 50ms. When the percentage is computed, we end up with negative numbers.

Therefore, we want to "fill in" the NULL values with zeroes, which we can do with PostgreSQL's `coalesce` function, which returns the first non-null value from its arguments. Here's what we get:

```sql
SELECT
  name AS endpoint,
  count(*) AS hits,
  quantile(duration, 0.5) AS median_duration,
  quantile(duration, 0.95) AS ninety_fith_percentile_duration,
  avg(coalesce((
    SELECT sum(duration)
    FROM jsonb_to_recordset(events->'sql') AS x(duration NUMERIC)
  ), 0)) AS avg_time_in_sql
FROM transactions
WHERE
  app_bin_id = #{ActiveRecord::Base.sanitize @app_bin_id} AND
  type = 'request_response' AND
  start > (current_timestamp - interval '1 day')
GROUP BY endpoint
ORDER BY hits DESC;
```

We just need to repeat this pattern for each of the percentage columns. Here’s the first iteration of what we get:

```sql
SELECT
  name AS endpoint,
  count(*) AS hits,
  quantile(duration, 0.5) AS median_duration,
  quantile(duration, 0.95) AS ninety_fith_percentile_duration,
  avg(coalesce((
    SELECT sum(duration)
    FROM jsonb_to_recordset(events->'sql') AS x(duration NUMERIC)
  ), 0)) AS avg_time_in_sql,
  avg(coalesce((
    SELECT max(duration) - (
      SELECT sum(duration)
      FROM
        jsonb_to_recordset(events->'sql')
          AS y(duration NUMERIC, start TIMESTAMP, stop TIMESTAMP)
      WHERE
        y.start >= min(x.start) AND y.stop <= max(x.stop)
    )
    FROM
      jsonb_to_recordset(events->'view')
        AS x(duration NUMERIC, start TIMESTAMP, stop TIMESTAMP)
  ), 0)) AS avg_time_in_view,
  avg(coalesce((
    SELECT sum(duration)
    FROM
      jsonb_to_recordset(events->'controller_action')
        AS x(duration NUMERIC)
  ), 0)) AS avg_time_in_app,
  avg(coalesce((
    SELECT sum(duration)
    FROM jsonb_to_recordset(events->'other') AS x(duration NUMERIC)
  ), 0)) AS avg_time_in_other
FROM transactions
WHERE
  app_bin_id = #{ActiveRecord::Base.sanitize @app_bin_id} AND
  type = 'request_response' AND
  start > (current_timestamp - interval '1 day')
GROUP BY endpoint
ORDER BY hits DESC;
```

We need to some additional computation with the "View" column, since it may be the case that SQL events happen while a View event is running. For that, we just need to subtract out those SQL events.

There is one major issue with this query: it is extremely slow when when the dataset gets reasonably large (For instance, once we hit about 1000 records, the entire thing takes about a second to execute. After 10000 records, it lasts 10 seconds and grows roughly linearly from that). This is due to the fact that we’re averaging over the entire dataset multiple times, with each record generating a set of at least five virtual tables.

We are in the process of curbing this by computing most of these values ahead of time. For example, we could add columns to the Transactions table where we compute the values for SQL/View/etc. time, thus curtailing the need for those virtual tables. We have to be careful, however, since this would add some time to our data intake workflow. This may be negligible for less complicated transactions, but it’s worth it to consider transactions with hundreds of events.

Another way to optimize massive aggregate queries like this would be to cache the results. While caching strategies almost always sacrifice “freshness” of data for speed, we don’t necessarily need to worry about this, especially since we are only receiving data from our agents on a minute-by-minute bases, rather than a millisecond-by-millisecond basis. For now, we don’t currently utilize a caching solution for this, but it’s on the roadmap.

In the case of the waterfall diagram, we perform a similar query, except for a single transaction record. We simply pull its events and order them by start time. This alone would be sufficient, but we decided that we wanted to group “n+1” operations together, so that we can both compress the chart and provide more useful information for those wanting to optimize their workflows. To accomplish this, we add an additional “count” column to our query output, grouping by “identifier.” This identifier is what we use to further sort out events. For example, a `SELECT` query will have a different signature from an `INSERT` query. If we are `SELECT`ing multiple times from a certain table in a row, this indicates a possible n+1 query. We just use some simple regular expressions to parse out these identifiers.

Here are the main ideas we took away when planning out how we query our data:

- Database-level computation is almost always faster than application-level computation. Calculations that span across thousands of records should be performed as close to the database as possible.
- With that in mind, it’s a good practice to have the data ready for consumption and presentation by the time it reaches the interface. This practice allows us to focus on presentation on the front end. While it is sometimes necessary to transform the data in the browser to some degree (especially since, in our case, JSON does not have a “date” datatype built in), it’s good to let our server handle most of that work.
- It is best to find ways minimize operations that impact query performance, such as JOINs and aggregates. SQL provides a great deal of flexibility when it comes to performing different kinds of queries, but this comes at the cost of performance, especially when we are dealing with many records at once. Indexes can only go so far in this regard.

## Further Considerations
Our application is unique in the world of application performance monitoring solutions in that we only need to consider 24 hours of data. If we wanted to expand our service to include more historical data, we would need to take into consideration datasets that are considerably larger than the ones with which we are currently working.

## Conclusion
Tracebin is the result of a month of studying, building, and head-to-wall contact. Through the process, we learned not only how to deal with several problems across multiple domains, but also how to plan, communicate, and manage a sizable project of fairly significant scope.

We’d like to give special thanks to our mentors at Launch School. Without their gracious support and advice, this project wouldn’t be a tenth of what it is today.
