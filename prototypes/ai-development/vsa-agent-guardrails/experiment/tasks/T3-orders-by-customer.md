---
id: T3
title: List a customer's orders
kind: slice-local
scope.sliced: src/Orders.Api/Features/*Customer*, src/Orders.Api/Features/*Customer*/**, tests/Orders.SliceTests/**
scope.layered: src/Orders.Application/Orders/Queries/*Customer*, src/Orders.Application/Orders/Queries/*Customer*/**, src/Orders.Application/DependencyInjection.cs, src/Orders.Application/Orders/OrderDtos.cs, src/Orders.Api/Endpoints/**, src/Orders.Api/Program.cs, tests/Orders.IntegrationTests/**
---
Add a way to list one customer's orders.

`GET /customers/{customerId}/orders` returns `{ "orders": [ ... ] }` with the same summary shape as `GET /orders`, newest first, containing only that customer's orders. An unknown customer returns 200 with an empty list.

Add tests. Run them before you finish.
