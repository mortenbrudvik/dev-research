---
id: T2
title: Shipped orders cannot be cancelled
kind: slice-local
scope.sliced: src/Orders.Api/Features/CancelOrder/**, src/Orders.Api/Domain/CancellationPolicy.cs, tests/Orders.SliceTests/**
scope.layered: src/Orders.Application/Orders/Commands/CancelOrder/**, src/Orders.Domain/Policies/CancellationPolicy.cs, tests/Orders.IntegrationTests/**
---
Shipped orders can no longer be cancelled.

`POST /orders/{id}/cancel` on a Shipped order must return 409 with a ProblemDetails whose `detail` says that shipped orders cannot be cancelled. Pending orders still cancel as before; already-cancelled orders still return 409; unknown orders still return 404.

Update or add tests so that the suite reflects the new rule. Run the tests before you finish.
