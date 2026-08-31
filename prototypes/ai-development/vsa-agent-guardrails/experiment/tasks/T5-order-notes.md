---
id: T5
title: Optional notes on an order
kind: persistence
scope.sliced: src/Orders.Api/Domain/Order.cs, src/Orders.Api/Platform/Persistence/**, src/Orders.Api/Features/CreateOrder/**, src/Orders.Api/Features/GetOrder/**, tests/Orders.SliceTests/**, CLAUDE.md
scope.layered: src/Orders.Domain/Entities/Order.cs, src/Orders.Infrastructure/Persistence/**, src/Orders.Application/Orders/Commands/CreateOrder/**, src/Orders.Application/Orders/Queries/GetOrder/**, src/Orders.Application/Orders/OrderDtos.cs, tests/Orders.IntegrationTests/**, CLAUDE.md
---
Orders get an optional free-text `notes` field of at most 500 characters.

It can be set when creating an order (`"notes"` in the `POST /orders` body, optional) and is returned by `GET /orders/{id}` as `"notes"` (null when not set). A value longer than 500 characters is a validation error (400). Persist it in the database with a new migration.

Add tests for creating with notes, creating without notes, the length limit, and reading notes back. Run the tests before you finish.
