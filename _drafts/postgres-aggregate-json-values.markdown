---
title: Using PostgreSQL to aggregate JSON values
category: programming
summary: PostgreSQL provides a JSON datatype to store structured data, allowing us to quickly store and query different kinds of data without having to use JOINs on multiple datasets. Let's see how we can use this to our advantage and leverage the speed of PostgreSQL to perform operations on that data before we even import it to our application.
subtitle: Get the data you need from a JSON column before it hits your application.
---

## Trouble in JOIN Land

Say we have a simple time tracking application. For each business day, a user logs the time they take for certain tasks. There's an additional table for logging their breaks. A real-world schema probably wouldn't look like this, but bear with me for now. I suppose we want breaks and tasks presented as separate datasets, or maybe we want a `NOT NULL` constraint on a task's description, but not for that of a break.

```
business_days

 Column  |  Type
---------+---------
 id      | integer
 user_id | integer (users table not listed)
 day     | date

tasks

   Column        |   Type
-----------------+------------
 id              | integer
 description     | text
 start           | timestamp
 finish          | timestamp
 business_day_id | integer

breaks

   Column       |   Type
----------------+------------
id              | integer
description     | text
start           | timestamp
finish          | timestamp
business_day_id | integer
```

We want to calcualte the average amount of time it takes for a person to complete each task. For that, let's start with the following query:

```sql
SELECT AVG(finish - start)
  FROM tasks
  GROUP BY description;
```

This particular query doesn't select for users, so it aggregates on *all* users, returning the average time for all users to complete each task. To filter by user, we'll need to add a JOIN.

```sql
SELECT bd.user_id, t.description, AVG(t.finish - t.start)
  FROM tasks AS t
  INNER JOIN business_days AS bd
    ON bd.id = t.business_day_id
  GROUP BY bd.user_id, t.description;
```

This will group our averages by user ID and description. If we want the username, we'd need an additional join.

```sql
SELECT u.id, t.description, AVG(t.finish - t.start)
  FROM tasks AS t
  INNER JOIN business_days AS bd
    ON bd.id = t.business_day_id
  INNER JOIN users AS u
    ON u.id = bd.user_id
  GROUP BY u.name, t.description;
```

If we wanted to add breaks into the mix, this will be a little more cumbersome, with additional JOINs thrown into the mix.

JOINs take a lot of time, especially when we are selecting for specific values on the JOIN predicate. Let's say we have hundreds of thousands of records--these queries might bottleneck our application's performance. Furthermore, `tasks` and `breaks` have similar characteristics, so a separate table might be a little redundant, especially considering we’re using it in a similar way.

JOINs make a database very flexible. We can query a database in many different ways using JOINs, leaving the data open for future possibilities. It’s a hallmark of the power of relational databases. However, this comes at the cost of performance, and in our application we might want to consider a different approach.

## Enter JSON Land
Say we know how we’re going to query our database each time. It would make sense to denormalize some of our data into one table, for the sake of speeding up our queries. This comes at the expense of flexibility, but we’ve weighed those tradeoffs. Naturally, we would want to do this to our `business_days` table. There are a few ways of doing this.

The naive approach would be to add columns to our table for each task/break we expect our employees to take on during the day.

```
business_days

 Column        |  Type
---------------+---------
 id            | integer
 user_id       | integer (users table not listed)
 day           | date
 event_1_desc  | character varying
 event_1_start | timestamp
 event_1_end   | timestamp
 event_2_desc  | character varying
 event_2_start | timestamp
 event_2_end   | timestamp
  ...
```

You can see the trouble we’re going to have here. Not only will this be difficult to aggregate (one day’s `event_1_desc` might be `’data entry'`, while another’s might be `’meetings'`), but it’ll leave a whole lot of blank fields and overflows (if we go up to `event_(n)`), what’s to say an employee might log n + 1 events in a day? We seem to be in a pickle.

Before we migrate over to MongoDB, let’s take a look at what our existing database has to offer. We need a way to add arbitrary amounts of data to a single table, preferably a single column. PostgreSQL gives us the ability to do this with the JSON datatype.

Let’s modify our `business_days` table to do that. We’ll create a JSON column called `events`, where we’ll put some sort of JSON object to represent tasks and breaks.

```
business_days

 Column  |  Type
---------+---------
 id      | integer
 user_id | integer (users table not listed)
 day     | date
 events  | jsonb
```

While we can imagine a pretty complicated JSON object structure for this containing the start and end times, event type, and so on (what we’ll discuss below will absolutely be able to accommodate such a data structure with some tweaks), but for now let’s just make something as simple as possible. Let’s say we’re only concerned with the duration of the event, and we’ll compute it before we dump it into the database. Here’s what I mean:

```json
{
  "meetings": 2,
  "data entry": 4
}
```

So the keys are the event description, and the values are the duration in hours. At the end of the day, our employee will log a business day into the system with values like this.

So far, so good. Let’s say we now want to do what we were doing above: compute the average duration of each event description over the span of the table’s business days. We could pull the entire raw JSON object out of the database and into our application layer, but since speed is our primary concern, it might be beneficial to keep these computations on the database layer.

The [JSON function documentation](https://www.postgresql.org/docs/current/static/functions-json.html) gives us quite a few options to handle this, but the one that looks like the most useful is the `json_each` function. Let’s start with a trivial example:

```sql
SELECT json_each('{"a":4, "b":3}');
```

This will return the following results:

```
 json_each
-----------
 (a,4)
 (b,3)
(2 rows)
```

So the rows wind up being `setof` tuples for each key/value pair in the object. Perhaps we can turn this into a table. Their documentation gives us a hint:

```sql
SELECT *
  FROM json_each('{"a":4, "b":3}');
```

This will return the following results:

```
 key | value
-----+-------
 a   | 4
 b   | 3
(2 rows)
```

Quite nice! This will return a virtual table, the columns for which are the keys and values of our JSON object. Perhaps we can form a virtual table with multiple objects, and group by its keys! Let’s plug in some of our data.

```sql
SELECT json_each(business_days.events)
  FROM business_days;
```

This returns:

```
    json_each
------------------
 ("data entry",4)
 (meetings,2)
 ("data entry",3)
 (meetings,5)
(4 rows)
```

This gives us tuples for each key/value pair in our table. Our table contains two rows, each with an object containing some events. Let’s morph it into a virtual table.

```sql
SELECT (json_each(business_days.events)).*
  FROM business_days;
```

returns:

```
    key     | value
------------+-------
 data entry | 4
 meetings   | 2
 data entry | 3
 meetings   | 5
(4 rows)
```

So close! We can now imagine this to be a new table that we can query on, so let’s try to group together the keys and average that group’s values.

```sql
SELECT kv.key, AVG(kv.value)
  FROM (
    SELECT (json_each(business_days.events)).*
      FROM business_days
  ) AS kv
  GROUP BY kv.key;
```

This gives us:

```
ERROR:  function avg(json) does not exist
LINE 1: SELECT kv.key, AVG(kv.value)
                       ^
HINT:  No function matches the given name and argument types. You might need to add explicit type casts.
```

Okay, the `value` column doesn’t seem to contain the appropriate type of data. Let’s try casting the value:

```sql
SELECT kv.key, AVG(kv.value::numeric)
  FROM (
    SELECT (json_each(business_days.events)).*
      FROM business_days
  ) AS kv
  GROUP BY kv.key;
```

Gives us:

```
ERROR:  cannot cast type json to numeric
LINE 1: SELECT kv.key, AVG(kv.value::numeric)
                                   ^
```

It’s still considering the column to be of type JSON, and I guess we can’t make it a numeric value. Let’s see if JSON can become text, which we’ll definitely be able to cast as a numeric.

```sql
SELECT kv.key, AVG(kv.value::text::numeric)
  FROM (
    SELECT (json_each(business_days.events)).*
      FROM business_days
  ) AS kv
  GROUP BY kv.key;
```

This returns:

```
    key     |        avg
------------+--------------------
 data entry | 3.5000000000000000
 meetings   | 3.5000000000000000
(2 rows)
```

Exactly what we need! Let’s add a little more data to our table and see how we can group by users. We’ll just need to add the `user_id` column to our subquery and group by that in our outer query. We’ll also give useful names to the columns in the resulting table:

```sql
SELECT kv.user_id, kv.key AS description, AVG(kv.value::text::numeric) AS avg_hours
  FROM (
    SELECT user_id, (json_each(business_days.events)).*
      FROM business_days
  ) AS kv
  GROUP BY kv.user_id, kv.key;
```

This gives us:

```
 user_id | description |     avg_hours
---------+-------------+--------------------
       2 | meetings    | 2.0000000000000000
       2 | breaks      | 4.0000000000000000
       1 | data entry  | 3.5000000000000000
       1 | meetings    | 3.5000000000000000
(4 rows)
```

## Conclusion / Further Exploration
The JSON datatype in PostgreSQL is a powerful way to store arbitrary, denormalized data for speedy queries. With a little work, we can perform aggregate functions and various calculations on our JSON objects before we even make it out of the database layer. Furthermore, the JSON datatype gives us back a little bit of flexibility we might’ve otherwise missed out on when we denormalized our tables.
