---
id: T4
title: Audit trail for every command
kind: cross-cutting
scope.sliced: src/Orders.Api/Domain/**, src/Orders.Api/Platform/**, src/Orders.Api/Features/**, tests/Orders.SliceTests/**
scope.layered: src/Orders.Domain/**, src/Orders.Application/**, src/Orders.Infrastructure/**, src/Orders.Api/**, tests/Orders.IntegrationTests/**
---
Record an audit trail for every operation that changes an order — creating and cancelling today, and any command added later: who (the value of an `X-User` request header, or "anonymous" when absent), what (the operation name), when, and the order id. An entry must be persisted in the same transaction as the change it records.

Expose `GET /orders/{id}/audit` returning `{ "entries": [ { "actor", "action", "at" } ] }`, oldest first; 404 for an unknown order.

Add tests showing that creating and then cancelling an order produces two entries with the right actor and action, and that an unknown order returns 404. Run the tests before you finish.
