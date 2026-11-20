Most systems talk to something outside themselves: a schedule, a database, a queue, a mail server. Dapr bindings let your app do that through one small API, with the details in YAML.

In this 30-minute lab you'll use Dapr bindings from .NET, Python, or Java. You'll start with a cron input binding that calls your app on a schedule, without any Dapr code in the app. Then you'll use the PostgreSQL output binding to insert, query and purge rows with plain SQL.

Next you'll point the State API and a binding at the same database and compare what each one gives you. Finally, you'll combine bindings with service invocation, as one app pings another on a schedule and logs every answer to the database.

You'll finish knowing when a binding is the right tool, how input and output bindings differ, and when the State API is the better choice.
