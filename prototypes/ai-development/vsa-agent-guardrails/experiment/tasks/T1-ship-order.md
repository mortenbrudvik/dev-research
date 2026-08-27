---
id: T1
title: Ship an order
kind: slice-local
scope.sliced: src/Orders.Api/Features/Ship*, src/Orders.Api/Features/Ship*/**, tests/Orders.SliceTests/**
scope.layered: src/Orders.Application/Orders/Commands/Ship*, src/Orders.Application/Orders/Commands/Ship*/**, src/Orders.Application/DependencyInjection.cs, src/Orders.Application/Orders/OrderDtos.cs, src/Orders.Api/Endpoints/OrdersEndpoints.cs, tests/Orders.IntegrationTests/**
---
Add the ability to ship an order.

`POST /orders/{id}/ship`:
- 404 for an unknown order.
- 409 (ProblemDetails, title "Business rule violated") if the order is not Pending.
- Otherwise 200 with `{ "id", "status", "shippedAt" }`, and the order is stored as Shipped with the shipping time.

Add tests covering all three outcomes, following the conventions of the existing tests. Run the tests before you finish.
