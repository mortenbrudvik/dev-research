---
title: Vertical Slice Architecture for AI Development
description: Why organising code by use case gives AI coding agents a bounded context, a bounded blast radius, and tests as back pressure — Jimmy Bogard's 2026 argument, what the evidence supports, where it breaks, and how to make the rules mechanical rather than cultural.
tags: [ai, agents, architecture, vertical-slice, code-quality]
---

# Vertical Slice Architecture for AI Development

*Why organising code by use case gives AI coding agents a bounded context, a bounded blast radius, and tests as back pressure — Jimmy Bogard's 2026 argument, what the evidence supports, where it breaks, and how to make the rules mechanical rather than cultural.*

**Status:** current as of August 2026. The anchor talk was published on 2026-08-24; every statistic and tool version below is dated and sourced in [References](#11-references). Quotations from the talk are taken from its captions and may differ from the spoken wording by a word or two.

---

## Table of contents

1. [The claim](#1-the-claim)
2. [Why now: the cost of code moved](#2-why-now-the-cost-of-code-moved)
3. [What a vertical slice is](#3-what-a-vertical-slice-is)
4. [Why layers do not guardrail an agent](#4-why-layers-do-not-guardrail-an-agent)
5. [Three guardrails a slice gives an agent](#5-three-guardrails-a-slice-gives-an-agent)
6. [Where slicing goes wrong on its own](#6-where-slicing-goes-wrong-on-its-own)
7. [Making the rules mechanical](#7-making-the-rules-mechanical)
8. [The limits](#8-the-limits)
9. [A decision guide](#9-a-decision-guide)
10. [Applying it: a starter checklist and a prototype](#10-applying-it-a-starter-checklist-and-a-prototype)
11. [References](#11-references)

---

## 1. The claim

Jimmy Bogard — who named Vertical Slice Architecture (VSA) in a 2018 blog post after presenting it since 2015, and who created MediatR and AutoMapper — gave a 45-minute Codeartify session on 20 August 2026, published on YouTube on 24 August: *Vertical Slice Architecture: Effective Guardrails for AI Development*. It is his first extended public treatment of AI-assisted development; apart from the July 2026 announcement of this session, his blog's 2025–2026 posts are release and licensing notes. The argument, compressed:

> With coding agents, *writing* code costs almost nothing, so the cost of software is now the cost of **verifying and changing** it. Agents are not immune to bad structure: they read the repository and copy what they find, and layered architectures do not constrain them, because "the interfaces themselves only constrain compilers. They don't constrain agents." Organising code by **use case** — one vertical slice from request to response — gives an agent three guardrails: **one slice is one context window**; **the slice boundary is the blast radius** of a change, which bounds what a review has to consider; and **tests through the slice's entry point are the back pressure** that stops the generative loop from getting ahead of itself. But a slice does not keep itself honest. The rules have to be **mechanical, not cultural** — architecture tests, rules files in the repository, a reference slice, small sessions, a scheduled dedup pass — because "an agent cannot read your culture … but it can read a failing test."

This guide restates that argument with its sources checked (sections 2–7; several of the talk's figures and attributions needed correcting), then gives the strongest counter-arguments (section 8), a decision guide (9), and a checklist with a prototype to build (10).

One thing to say up front. As of August 2026 **no study compares slice-organised code with layered code as a treatment** for agent success rate, tokens per task, review time, or defects. The thesis is a mechanism argument, backed by experience reports from several independent practitioners and by indirect measurements (how agent success falls with the number of files a change touches; how token use falls in cleaner repositories). The guide says which claims rest on which.

---

## 2. Why now: the cost of code moved

After a few minutes on his own experience — reviewing 800 generated lines takes as long as writing them — Bogard turns to numbers. They are directionally right, but the sourcing in the talk is loose; here is what the primary sources actually say.

| In the talk | What the source says |
|---|---|
| Stack Overflow 2025: 66% of developers' "biggest frustration" is AI that is "almost right, but not quite" | The 2025 Developer Survey (49,000+ responses) asked a multi-select question about problems encountered. 66% selected "AI solutions that are almost right, but not quite" — the most-cited item; 45.2% selected "Debugging AI-generated code is more time-consuming". Bogard's follow-on — that finishing took as much work as "the other 90%" — is his own gloss, not a survey finding. |
| "A company's internal analysis of their own tooling": +242% production incidents per PR, PR size +51% | Faros AI, *AI Engineering Report 2026* (April 2026): telemetry from 22,000 developers on 4,000+ teams across Faros's customer base. Comparing each team's two lowest-AI-adoption quarters with its two highest: **+242.7% incidents per PR, +51.3% average PR size, +441.5% median time in PR review, +31.3% PRs merged without any review, +861% code churn**. Correlational, vendor-produced, cross-customer — not one company studying itself. |
| GitClear: 3.88% refactored lines, down from 21% in 2022; copy-paste 5× more likely than refactoring; duplicated blocks +81% since 2023, for an organisation that went "100% agentic" | GitClear, *The Maintainability Gap* (mid-2026; 623 million analysed changes from 2023–2026 across many organisations, about a quarter of commits AI-assisted): moved/refactored code fell from **21% of changed lines (2022) to 13% (2023) to 3.8% year-to-date 2026**; copy/paste rose from 9.4% to 15.7% (GitClear's own "~5×"); duplicated blocks per million changed lines rose from 40.3 to 73.0 (**+81%**); cross-file function calls fell 35%. Industry-wide data, not one organisation. |
| "DORA last year": agentic AI "does not fix anything in the team, it merely amplifies what's already there" | DORA 2025, *State of AI-assisted Software Development* (~5,000 respondents): "AI's primary role is as an amplifier." The sentence Bogard paraphrases is from the announcement by Nathen Harvey and Derek DeBellis: "AI doesn't fix a team; it amplifies what's already there." The report is about AI assistance generally, not agents. DORA 2024 had quantified the cost: per 25% increase in AI adoption, an estimated **−1.5% delivery throughput and −7.2% delivery stability**; in 2025 throughput turned positive while stability stayed negative. |
| "Some surveys" found experienced developers slower with AI; "this company" found its most experienced developers slower because they had not invested in tooling | The talk names no source. The only published study matching the claim is METR's randomised controlled trial (July 2025): 16 experienced open-source developers, 246 real issues, **19% slower with AI** (95% CI +2% to +39%) while forecasting they would be 24% faster. If that is the source: METR is a non-profit lab, not a company, and it did not blame tooling investment; its "likely contributing" factors include **large, complex repositories** (averaging 1.1M+ lines) and **implicit repository context** the AI lacks — closer to Bogard's thesis than his gloss. (The spoken description — "throughput of the system", "tickets going through" — also fits company telemetry such as Faros's July 2025 report, which found lower adoption among senior engineers, not slower work.) A February 2026 METR follow-up was inconclusive because 30–50% of participants declined to submit some tasks in the no-AI condition, biasing the sample. |

Bogard himself flags the second and third rows as vendors "trying to sell something that fixes this problem" and "not peer-reviewed studies". As he says himself, "the direction is pretty constant across every single source … the magnitude is not": more code, larger changes, more review load, more instability. Addy Osmani's *The 70% problem* (December 2024) is the earlier articulation of the same experience: the last 30% "still requires real engineering knowledge".

From this he derives a cost model. Two costs make up software: authoring, and verifying-plus-changing. Agents drove the first towards zero — "code is more disposable than it ever was" — while the second "hasn't really changed", so it is now the bottleneck, "even if it's done by agents". (Zero is a statement about labour, not spend — he adds "obviously, there's token costs"; Anthropic's own figure for Claude Code is about $13 per developer per active day.) The framing sentence he borrows, "the cost of software is approximately equal to the cost of changing it", is Kent Beck's *Constantine's Equivalence* (Tidy First?, 2023), which Ian Cooper quoted in 2024 while arguing that the cost of software is in ownership, not authorship. And the business "doesn't care who writes the code" but "still blames someone when something goes wrong" — "I can't really say it's Claude's fault."

So the question becomes: *which application architecture is cheapest to verify and change?* And, since an agent pays for context in tokens rather than thinking time, its sharper form: "do they need to — should they have to — look at the context of the entire system in order to make one single change?"

---

## 3. What a vertical slice is

Bogard's teams at Headspring (Austin) started a long-term project on an onion architecture in the early 2010s, hit its limits within months, moved to CQRS "before it had that name", and reorganised the code around requests instead of layers. The practice is documented from October 2013 ("feature folders"), was presented at NDC Oslo in 2015 as *SOLID Architecture in Slices not Layers*, and got its name in the April 2018 post *Vertical Slice Architecture*:

> "In this style, my architecture is built around distinct requests, encapsulating and grouping all concerns from front-end to back. You take a normal 'n-tier' or hexagonal/whatever architecture and remove the gates and barriers across those layers, and couple along the axis of change … **Minimize coupling between slices, and maximize coupling in a slice.**"

The observation behind it: a feature change is a full-stack change — UI, domain, data access, database — but layered code is filed by *what the code is concerned with internally*, so every change scatters across folders. VSA files code by *how it changes*. "With this approach, most abstractions melt away, and we don't need any kind of 'shared' layer abstractions like repositories, services, controllers", and "new features only add code, you're not changing shared code and worrying about side effects."

The granularity is the **use case**, not the module. Asked in the Q&A whether a slice is "InvoiceManagement" or "DeleteInvoice", Bogard answered: "Use case." A slice is one request in, one response out, with the validation, the handler, and the persistence it needs, and (in the sliced repositories he maintains) a test file per slice in a mirrored folder of the test project. What is *not* in a slice: cross-cutting concerns "that do not have any kind of domain or business logic" (auth, logging, pipeline behaviours), and the shared persistence and domain model underneath — "the domain model is shared (and should be), since our domain's boundary is larger than a single use case."

The difference on disk, using the layered sample he takes apart in the talk and the sliced sample he recommends. Microsoft's reference application (`dotnet/eShop`, the 2023 successor to the eShopOnContainers he names on the slide) is the layered example; his own fork (`jbogard/eShop`, branch `vsa/start`) reorganises the same application into slices, though its layout was not inspected for this guide:

```text
src/Ordering.API/            Apis/OrdersApi.cs, Apis/OrderServices.cs   (endpoints + a shared parameter object)
src/Ordering.Domain/         AggregatesModel/…, Events/…                (entities)
src/Ordering.Infrastructure/ Repositories/…, EntityConfigurations/…     (persistence)
```

His ContosoUniversity sample is the sliced one — one Razor Page per use case, with the request, validator and handler nested in the page model, and a test file per slice:

```text
Pages/Students/Create.cshtml.cs     class Create : PageModel
                                      record Command : IRequest<int>
                                      class Validator : AbstractValidator<Command>
                                      class CommandHandler : IRequestHandler<Command, int>
Pages/Students/Delete.cshtml.cs
Pages/Students/Details.cshtml.cs
Pages/Students/Edit.cshtml.cs
Pages/Students/Index.cshtml.cs
IntegrationTests/Pages/Students/CreateTests.cs   sends Create.Command through the fixture, asserts the row
```

Adding a use case — cancel an order, withdraw a student — touches three projects in the first layout (`Ordering.API`, `Ordering.Domain`, `Ordering.Infrastructure`) and adds one file pair in the second.

How VSA relates to the architectures it is usually contrasted with:

- **Clean, Onion, Hexagonal.** Orthogonal, not opposed. Derek Comartin: "The point of vertical slices is about cohesion. Clean (or Onion) Architecture is about the direction of dependencies … They are orthogonal concerns and not mutually exclusive." Milan Jovanović's comparison (August 2026): "Clean Architecture couples by layer … Vertical Slices couple by feature." Bogard notes that none of those architectures' authors are "anti-vertical slice"; his objection is that without the vertical cut "it doesn't really solve the coupling problem".
- **Modular monoliths and bounded contexts** are the macro boundary; slices are the micro pattern inside them. Jovanović: "Modules define the boundaries of the system. Vertical slices organize the code within those boundaries." Bogard, Q&A: "Vertical slice is for organizing the code for a use case. Bounded contexts are about defining boundaries for a domain as a whole." Large systems still get large; slices make it easier to "extract slices into modules and then modules into bounded context".
- **CQRS.** Built in: commands and queries are different requests, so "moving towards a vertical slice architecture gives me CQRS out of the gate."
- **REPR** (Request-Endpoint-Response, Steve "ardalis" Smith, 2020) is the same request-in/response-out idea packaged per endpoint.

Tooling, in .NET where the style is most established: MediatR (the request/handler shape since 2014; from July 2025 versions 13+ are dual-licensed RPL-1.5/commercial through Bogard's Lucky Penny Software, with a free community tier and 12.5 remaining Apache-2.0), Wolverine (handlers as plain static methods, explicitly VSA-first), FastEndpoints (REPR), Carter, and plain ASP.NET Core Minimal APIs. Elsewhere the same idea goes by other names — Java's "package by feature, not layer", Angular's folders-by-feature style rule, React's "group by feature or route", Go's package-by-feature with `internal/`, Shopify's packwerk packages in Rails — none of which cite Bogard; treat them as convergent practice. Frontend **Feature-Sliced Design** is a different methodology despite the word: it keeps seven horizontal layers and slices *within* them.

---

## 4. Why layers do not guardrail an agent

Layered architectures promised independence from frameworks, UI, database and external dependencies. Bogard's verdict, from a consulting project over a decade ago, is that changing any of those was *harder* under layers, not easier — "the verdict was false". That was the human-era argument. The agent-era argument is different, and it is the talk's central move.

The natural instinct when agents arrived was to let the layers guardrail them: put the right code in the right drawer, isolate each layer behind interfaces, and the agent cannot affect too much at once. But:

> "The interfaces themselves only constrain compilers. They don't constrain agents. The agents can look at the entire codebase and make whatever change they want. They can break whatever rules that are in your head."

And they will make up rules if you do not give them any — "just like the experience I've had with training junior developers." The crucial property is what an agent *reads*: "the agents can't and don't read architecture diagrams. It just reads your repo and copies exactly what it finds." Draw.io and Miro are invisible; the repository is the specification. Hence his closing slogan, "the repo, the code that's already there, is now the context and the prompt", and Jeremy D. Miller's independent June 2026 formulation from the Wolverine side: "The structure of your codebase is now, effectively, part of the prompt." This sits inside the mid-2025 vocabulary of *context engineering* (Tobi Lütke, Andrej Karpathy, collected by Simon Willison): the art of putting the right information, and only that, in the window.

Two pieces of supporting evidence the talk does not cite. Anthropic's own best-practice guide tells users to "reference existing patterns … follow the pattern" — the vendor instructs the agent to copy what it finds. And a study of 557 agent sessions (Gao and Chen, August 2026) found that instruction files and working notes accounted for 60.5% of agents' documentation interactions, classical documentation 10.6%, and API references 1.3%: architecture docs are read only if the rules file points at them. That agents imitate their surroundings is measured at the training-corpus level (Codex reproduced known buggy patterns up to twice as often as the correct version; ~40% of Copilot completions in security-sensitive scenarios were vulnerable); that they copy the *neighbouring slice* in-context is plausible and widely reported but not measured as such.

David Whitney's line, which Bogard cites — "your code quality is now directly proportional to how useful your tools are" — comes from a March 2026 post arguing that if design complexity explodes with repetitive code, the model cannot fit the relevant context or the signal is buried in noise, and "the quality of its contributions degrades". The proportionality runs both ways: bad code makes the tools worse, and worse tools make the code worse. When developers were the tools, quality tracked their experience; now it tracks the structure the tools are given.

The objection everyone raises next is Jovanović's (November 2025): "Vertical Slice Architecture removes the guardrails … This gives you speed and flexibility, but it shifts the burden of discipline onto you." Bogard's reply: it "removed the *illusion* of guardrails that layered architecture tries to put in place." He concedes the second half completely — "it definitely still shifts the burden of what to do with these smaller balls of mud onto you. But now *you* is now a machine, the agent with no specific taste or preference and can go forever." That sentence sets up everything from section 6 on.

---

## 5. Three guardrails a slice gives an agent

### 5.1 One slice, one context window

The first guardrail: "one slice is one context window for the agents."

The premise is **context rot** — the term was coined on Hacker News in June 2025 and documented by Chroma in July 2025 across 18 models: performance degrades as input grows, even on trivial tasks, and distractors compound with length. Anthropic's engineering guidance calls context "a finite resource with diminishing marginal returns"; the Claude Code documentation says its practices derive from one constraint — "Claude's context window fills up fast, and performance degrades as it fills." Code-specific benchmarks show the steepest drops (LongCodeBench: Claude 3.5 Sonnet from 29% to 3% as context grows towards 1M tokens). Bogard cites Aaron Stannard's rule (here in Stannard's own wording): "Think of each session the way you think of a good function: it has one job, it does it well, and it finishes." Stannard reached the slice conclusion on his own in March 2026: vertical-by-feature organisation, adopted for his own reading convenience, "made it much easier for Claude to explore relevant code when working in a given feature area."

The mechanism in a layered codebase: to change one behaviour the agent has to load at least the controller, the service, the domain object and the repository, in four folders; "most of what it's reading in those files is not the task at hand", and every one of those files "could be shared with a dozen other features". In a sliced one, "I'm only touching the code inside one specific folder for like 95% of the code". Whitney's rule for extraction refactorings — they "should operate on a strict subset of the context of the parent function" (written about human readers, in May 2025; the transposition to agents is Bogard's) — becomes: "any layer boundary that does not reduce the context for refactoring is just pure cost", paid in tokens instead of thinking time.

What the evidence supports:

- **Agent success collapses with the number of files a change touches.** SWE-bench Live (Microsoft, June 2025): single-file patches under five lines are solved 48% of the time; patches touching three or more files or over 100 lines fall below 10%; seven or more files, never. SWE-Bench Pro (September 2025): gold patches average 107 lines across 4.1 files, frontier models solve about 23%, and Claude Sonnet 4's dominant failure mode was context overflow (63.4% of failures). RepoRescue (July 2026) finds a "coordination cliff" between local and whole-codebase changes. Caveat: multi-file tasks are also intrinsically harder; no study isolates code organisation as the variable.
- **Cleaner *code* lowers context cost without changing pass rate.** SonarSource's controlled minimal-pair study (May 2026, Claude Code on six behaviourally identical repository pairs that differ in static-analysis violations and cognitive complexity, with architecture and dependencies held fixed): pass rate unchanged (91.3% vs 92.1%), but input tokens −7.1%, file revisits −33.8%, and on multi-module tasks file revisits −50.8%. This is the best direct evidence that code quality changes what the agent *reads* and what it pays for; it varied cleanliness, not organisation, so it does not test the slice thesis, and it is a cost result, not a correctness one.
- **Rule adherence decays with output volume.** A 1,650-session factorial study of Claude Code (May 2026): none of four rules-file structure variables changed compliance, but each additional function generated in a session lowered the odds of compliance by about 5.6%. Shorter sessions keep the rules alive.

The workflow forms of this guardrail already exist: Geoffrey Huntley's Ralph loop ("one item per loop … you only have approximately 170k of context window"), Claude Code's `/clear` between tasks and its advice to execute a written plan in a fresh session, and Thoughtworks' Radar note that a fresh window per iteration "avoids the quality degradation that comes from accumulated context, though at significant token cost".

### 5.2 The slice boundary is the blast radius

The second guardrail: "the slice boundary is now the blast radius of the change."

His example is from the layered eShop: a single parameter object holding all the dependencies for all the endpoints of an API (in `dotnet/eShop`, `OrderServices` and `CatalogServices`, injected into nearly every endpoint of their APIs — "something like 47 different references", his approximate count; on `main` today the parameter is used about 45 times in `CatalogApi.cs` and about 22 times in `OrdersApi.cs`, depending on how you count). Any endpoint that needs one more dependency edits a class every endpoint depends on. In the sliced version, the handler's dependencies "are just the dependencies of that use case and nothing else"; change it and "I'm not affecting whatsoever any other use cases in the system." Bogard reframes Jovanović's layer-versus-feature coupling (section 3) as organising by cohesion, "something we've always taught as a good thing".

The agent-specific point: "in a shared method a human feels that risk … we'll hesitate … an agent does not hesitate. It does not stop to ask." He qualifies it at once — agents "have gotten better at this, but they're still nowhere near perfect" — and the evidence is mixed (section 8.8). So "the review doesn't scale by just reading better, reading more, reading harder … it only scales by shrinking the amount of stuff that you can reach." In a sliced codebase the question a review exists to answer — *what could this have broken?* — "is a bounded answer. It's just that one individual feature." In a layered one it is not.

The pre-AI code-review literature is the quantitative backing the talk does not give. The Cisco/SmartBear study behind the "200–400 lines per review" rule (its year is as SmartBear reports it; the primary paper was not retrieved) found defect-discovery rates falling off beyond that size and beyond about 500 lines per hour; Google's 2018 study of nine million reviews found a median change of 24 lines, 90% of changes touching fewer than ten files, and a median time to first feedback under an hour for small changes versus about five hours for very large ones. Faros's +51% PR size and +441% review time are exactly the regression a bounded blast radius is meant to reverse, and DORA's 2025 capabilities model lists "working in small batches" among the seven practices that turn AI adoption into a gain. The same bound helps an agent reviewer: LLM evaluators recognise and favour their own generations and cannot reliably self-correct without external feedback, so an AI review is weaker back pressure than a failing test — which is guardrail 3.

### 5.3 Tests are the back pressure

The third guardrail: "tests are the back pressure to this process" — the thing that keeps the loop from "getting too far over its skis". Bogard cites Geoffrey Huntley; the sentence is from Huntley's June 2025 talk write-up: "A failing build or test applies pressure to the generative loop, refining outputs"; his Ralph post adds "anything can be wired in as back pressure to reject invalid code generation" — security scanners, static analysers, anything that fails fast. Compilation is the trivial case; tests are the real one: "wait, you've broken something. So pause writing new code and go fix the stuff that you've already done."

In a slice, arrange-act-assert becomes *build the request, execute the slice, assert on the response* (and on what was persisted). From ContosoUniversity, lightly shortened:

```csharp
[Collection(nameof(SliceFixture))]
public class CreateTests(SliceFixture fixture)
{
    [Fact]
    public async Task Should_create_student()
    {
        var cmd = new Create.Command { FirstMidName = "Joe", LastName = "Schmoe", EnrollmentDate = DateTime.Today };

        var studentId = await fixture.SendAsync(cmd);          // request in

        var student = await fixture.FindAsync<Student>(studentId);
        student.ShouldNotBeNull();                              // state out
        student.LastName.ShouldBe(cmd.LastName);
    }
}
```

The fixture starts SQL Server in a Testcontainer, runs the migrations, and resets the database between tests with Respawn. Jovanović's July 2026 version sends a real HTTP request through the endpoint against PostgreSQL 17 and asserts on the row. The test knows nothing about the handler's internals, which is the point: "Tests coupled to layers punish refactoring; tests coupled to behavior enable it." Kent Beck "would raise his hand and say this is how it was always supposed to be": test behaviour, not implementation; *layers are implementation details*, and a test full of mocks for layer interfaces has leaked them. That is classical TDD — Martin Fowler's *Mocks Aren't Stubs* (2004) and Ian Cooper's *TDD, Where Did It All Go Wrong* (2017) — applied at the handler seam. Unit tests move inward to the domain model; the slice test covers everything around it. (Bogard, in the Q&A, has stopped arguing about the labels: "There are fast tests, slow tests, and very slow tests.")

For an agent this is what makes "refactor freely" true: the agent can rework everything inside the handler, and the only tests that fail are the ones for that use case. Anthropic's guidance says the same from the other side: "Give Claude something that produces a pass or fail, and the loop closes on its own."

Three caveats the evidence adds:

- **Agents do not reliably write the tests.** Across 4,882 agent pull requests (July 2026), agents changed tests in only 49.6% of PRs that touched code under test, and 64.8% of Python PRs had no changed line executed by any existing test. "Every slice ships with a handler test" has to be a gate (section 7.3), not an expectation.
- **Behaviour tests do not catch structural drift.** In *Needle in the Repo* (March 2026), 13.3% of outcomes passed every functional test and still failed the structural (maintainability) oracle. That is why architecture tests are a separate guardrail (section 7.1).
- **A test written by the same agent in the same context encodes the same misunderstanding.** Anthropic recommends a writer/reviewer split precisely because "a fresh context improves code review since Claude won't be biased toward code it just wrote"; Beck lists "any indication that the genie was cheating, for example by disabling or deleting tests" among the signs to watch. The request/response contract of a slice is a natural seam for a second session to write the test against.

---

## 6. Where slicing goes wrong on its own

Bogard is explicit that VSA plus an unsupervised agent is not enough: "left alone, an agent will just copy the neighbouring slice instead of extracting what should be shared" — and it does not know what *should* be shared. It will reach into another slice "because that's the shortest path". It will "keep creating these layered classes that we hate" — `PersonManager`, `PersonHelper` — "because that's what it does" (presumably because that is what it finds in its training data). He calls the result "unsupervised slicing".

None of this is new; agents compound a human failure mode. Oskar Dudycz describes VSA teams turning into a "feature factory" where requirements "drift one after another, slice by slice". Anton Martyniuk's cases are concrete: `ProcessPayment` and `RefundPayment` shared validation until refunds needed different rules; two product DTOs shared a shape until search needed a rating field. Bogard's own 2018 post carried the warning: "If your team does not understand when a 'service' is doing too much to push logic to the domain, this pattern is likely not for you." Under agents, "the team" is a model that has no such understanding unless told.

The agent-specific evidence is consistent:

- SlopCodeBench (March 2026): when agents repeatedly extend their own code, structural erosion rises in 77% of trajectories; explicit quality guidance improves the starting point by up to a third "without affecting degradation rates" — rules files fix the intercept, not the slope.
- *Agentic Refactoring* (November 2025, 15,451 refactorings in agent PRs): agents refactor deliberately in about a quarter of commits, dominated by renames and type changes — "localized improvements", not design-level extraction.
- SWE-NFI (July 2026): the best agent reached 70% functional correctness but scored 0.0–1.3 on behaviour-preserving structural improvement, against 1.5 for human developers.
- Left to generate from scratch, agents "exhibit a strong tendency to generate monolithic code structures" (CLI-Tool-Bench, 2026) and produce a "modular mirage" — file separation without semantic cohesion.

Hence the talk's insistence on the step "everyone skips": red, green, **refactor**. Asked in the Q&A whether slicing produces duplication (the email-sending example), Bogard answered: "This is exactly the refactoring step that everyone skips (and assumes can be skipped in a layered architecture). VSA didn't remove the requirement to refactor, it necessitates it." His guards are the old idioms — the same answer continues "we go back to the old idioms like DRY, YAGNI etc." — and a person in the loop ("still also have the humans as well"). The sharper form of YAGNI he does not name is Sandi Metz's "duplication is far cheaper than the wrong abstraction". An agent "with no specific taste" running a dedup pass is the actor most likely to manufacture the `PersonHelper` the talk condemns — so the pass has to be gated by a duplication detector and the rule of three, with his human review kept (section 7.6).

---

## 7. Making the rules mechanical

"We need to make this mechanical, not cultural." Bogard's list: architecture tests; conventions in the repository, not in your head; a reference slice; smaller stories, tasks and sessions; a scheduled dedup pass with agents *and* humans. The principle: "an agent cannot read your culture, your norms, your implicit agreements between developers, but it can read a failing test. It can read those markdown files."

Two independent confirmations of the programme. OpenAI's *Harness engineering* post (February 2026) describes a ~1M-line codebase written entirely by Codex over five months: a ~100-line AGENTS.md that is "a map, not a 1,000-page instruction manual"; constraints "enforced mechanically via custom linters … and structural tests"; and "on a regular cadence … a set of background Codex tasks that scan for deviations, update quality grades, and open targeted refactoring pull requests." Thoughtworks' Technology Radar put "curated shared instructions for software teams" (committed CLAUDE.md/AGENTS.md and embedding agents in reference applications) at *Adopt* in November 2025 and April 2026, and "anchoring coding agents to a reference application" at *Assess* in November 2025 (a blip not carried into the April 2026 edition). Birgitta Böckeler's vocabulary is useful: **guides** steer the agent before it acts (rules files, examples), **sensors** check after it acts (tests, linters, structural analysis — fast and deterministic — versus LLM review, slow and probabilistic).

Of the mechanisms below, only tests, hooks and CI gates are truly mechanical. Rules files and reference slices are *guides* — the agent follows them well when they are specific, and forgets them as the session grows.

### 7.1 Architecture tests

The rule to encode is the one Bogard states in the Q&A: "Slices should not ever depend directly on each other. Move the shared logic to a location that reflects it is being intentionally shared." Asked whether static analysis or a model in CI should enforce it instead, he answered: "I've had the best results with tests. Static analysis tooling doesn't seem to be sophisticated enough to be able to describe the intended architectural rules. I wrote those tests before agentic tools, they just continue to provide use." And: "the model constrains the design, the architecture test constrains the code. The test is the guarantee the agent doesn't overstep the bounds." The remark about static analysis is about the tools he had tried, not a limit of the category: the linters in the table below express the slice rule directly, Böckeler's report at the end of this section shows an agent correcting against one, and ArchUnit-style tests are static analysis packaged so that the failure lands in the test run the agent already executes. Prefer whichever form your agent already runs.

Every mainstream ecosystem has a maintained tool for "a slice may not reference another slice", and most can also express "a slice may depend only on the shared kernel":

| Ecosystem | Tool (version, August 2026) | The slice rule |
|---|---|---|
| .NET | ArchUnitNET 0.13.4 | `Slices().Matching("MyApp.Features.(*)").Should().NotDependOnEachOther()` |
| .NET | NetArchTest.eNhancedEdition 1.4.5 (the original NetArchTest has had no release since May 2021 and no commit since July 2023) | `Types.InAssembly(asm).Slice().ByNamespacePrefix("MyApp.Features").Should().NotHaveDependenciesBetweenSlices()` |
| Java | ArchUnit 1.5.0 | `slices().matching("..myapp.(*)..").should().notDependOnEachOther()` |
| JS/TS | dependency-cruiser 18.2, eslint-plugin-boundaries 7.2, Nx `enforce-module-boundaries`, Sheriff 0.19.6 (last release September 2025) | a `from`/`to` rule with a capture group (below), or tag-based constraints |
| Python | import-linter 2.13 (`type = independence`), tach 0.35 | listed feature packages may not import each other, even indirectly |
| Go | `internal/` directories (compiler-enforced), go-arch-lint 1.18, depguard via golangci-lint | `features/<slice>/internal/` makes a cross-slice import a compile error |
| Rust | Cargo workspaces, private-by-default visibility | one crate per slice; a slice not listed in `[dependencies]` cannot be used |

A complete .NET test:

```csharp
using ArchUnitNET.Domain;
using ArchUnitNET.Loader;
using ArchUnitNET.xUnit;
using Xunit;
using static ArchUnitNET.Fluent.Slices.SliceRuleDefinition;

public class SliceRules
{
    private static readonly Architecture Architecture =
        new ArchLoader().LoadAssemblies(typeof(Program).Assembly).Build();

    [Fact]
    public void Slices_do_not_depend_on_each_other() =>
        Slices().Matching("MyApp.Features.(*)")
            .Should().NotDependOnEachOther()
            .Check(Architecture);
}
```

The companion rule — a slice may depend on nothing but the shared kernel — is a one-liner in NetArchTest.eNhancedEdition: `Types.InAssembly(asm).That().ResideInNamespace("MyApp.Features.CreateOrder").ShouldNot().HaveDependencyOtherThan("System", "Microsoft", "MediatR", "FluentValidation", "MyApp.Features.CreateOrder", "MyApp.Domain", "MyApp.Platform")` — the allow-list has to name the frameworks the slice uses, or the rule fails on its first run. (In a Minimal API project, `typeof(Program)` is visible to the test project only with `public partial class Program { }` at the end of `Program.cs`.) SSW's .NET 10 VSA template ships a production-grade version in `tests/WebApi.ArchitectureTests/FeatureTests.cs` — `Slices_Should_NotDependOnOtherSlices` enumerates slice namespaces and asserts pairwise, plus rules that every endpoint is named `*Endpoint`, sits exactly two namespace segments below `Features`, and has a validator in the same slice. The equivalent dependency-cruiser rule, adapted from its documentation:

```json
{
  "forbidden": [{
    "name": "no-inter-slice",
    "severity": "error",
    "from": { "path": "^src/features/([^/]+)/.+" },
    "to":   { "path": "^src/features/([^/]+)/.+", "pathNot": "^src/features/$1/.+" }
  }]
}
```

And in Python:

```ini
[importlinter]
root_package = myapp

[importlinter:contract:slices]
name = Slices do not import each other
type = independence
modules =
    myapp.features.create_order
    myapp.features.cancel_order
    myapp.features.list_orders
```

Böckeler's May 2026 report is the most detailed first-hand observation of an agent correcting against such a rule: "The agent violated the rules a handful of times after I introduced them, and then self-corrected based on dependency-cruiser feedback" — and, without those sensors and human review, it "was definitely compounding inadvertent technical debt." Her caveat matches *Needle in the Repo*: file- and function-level sensors impressed her most; "cross-file concerns like modularity and coupling were different."

### 7.2 Rules files: conventions in the repo, not in your head

Which file depends on the tool: `CLAUDE.md` (Claude Code; nested per-directory files load on demand, `@imports`, and `.claude/rules/*.md` can be scoped with a `paths:` frontmatter), `AGENTS.md` (an open convention released by OpenAI in August 2025, used by 60,000+ repositories, stewarded by the Linux Foundation's Agentic AI Foundation since December 2025; the nearest file in the tree wins, so each slice folder can carry its own), `.cursor/rules/*.mdc` with globs, and `.github/copilot-instructions.md` with path-scoped `*.instructions.md`. Claude Code reads AGENTS.md through a one-line `@AGENTS.md` import.

What to put in one is now reasonably well understood:

- **Specific, verifiable instructions — not repository overviews.** The ETH Zurich evaluation of AGENTS.md files (February 2026) found that context files did not generally improve task success and raised cost by over 20%, while *instructions* in them were followed closely (a tool named in the file was used about 160× more often). "Repository overviews, although popular and recommended by model providers, are not helpful." Anthropic's list of what belongs: commands the agent cannot guess, style rules that differ from defaults, test instructions, repository etiquette, architectural decisions, gotchas; what does not: "anything Claude can figure out by reading code" and file-by-file descriptions. Keep it under about 200 lines — "Bloated CLAUDE.md files cause Claude to ignore your actual instructions!"
- **The slice rules themselves.** The public VSA skills converge on the same five: one use case = one folder holding request, response, validation, handler and test; one entry point per slice; minimise coupling between slices, maximise it within; no premature shared abstractions; test each slice through its entry point. Bogard's recommended example of "conventions in agents files" is akka.net's AGENTS.md, which is mostly build and test commands plus hard constraints ("Keep pull requests small and focused (< 300 lines when possible)", "Extend-only design", "Never use: async void") — commands and rules, not prose.
- **Where an agent may and may not go.** Path-scoped rules and a "stop and ask" instruction for edits outside the slice are guides; the enforcement is in 7.3.

A starting point for a sliced .NET service, synthesised from the akka.net file, the published skills, and Anthropic's guidance:

```markdown
# Orders service — conventions for agents

- One use case = one folder under `src/Features/<UseCase>/` containing the request, the response,
  the validator, the handler, the endpoint mapping, and the slice test.
  `src/Features/CreateOrder/` is the reference slice: copy its shape, not its logic.
- Slices never reference other slices. Shared code lives in `src/Domain/` (entities, value objects,
  policies) or `src/Platform/` (persistence, auth, logging, pipeline behaviours). There is no
  `Common/`, `Helpers/` or `Shared/` folder; do not create one.
- Every slice ships with a test that sends the request through the entry point and asserts the
  response and the persisted state. Do not mock the database; `SliceFixture` starts one.
- Before finishing: `dotnet test tests/Architecture.Tests` (fails on any cross-slice dependency)
  and `dotnet test tests/Slice.Tests --filter <UseCase>`.
- Keep a change inside one slice. If the task needs edits under `src/Domain/` or `src/Platform/`,
  stop and say so before making them. Never create or edit migrations.
```

Two empirical warnings. A study of 2,303 real context files (2025–2026) found developers write test procedures (75.9%) and architecture (68.1%) into them but rarely guardrails for security or performance (about 15%). And, per the factorial study in 5.1, adherence decays with the amount of code generated in a session — another reason the slice, not the sprint, is the unit of a session.

### 7.3 Hooks and gates: from advisory to enforced

Anthropic draws the line itself: "Claude treats [CLAUDE.md files] as context, not enforced configuration. To block an action regardless of what Claude decides, use a PreToolUse hook instead", and "unlike CLAUDE.md instructions which are advisory, hooks are deterministic and guarantee the action happens." Its recommended ladder for verification runs from a check named in the prompt, to a `/goal` condition, to a deterministic Stop hook, to an adversarial review subagent.

The mechanics in Claude Code: a hook is a command run on an event (`PreToolUse`, `PostToolUse`, `Stop`, and others). **Exit code 2 blocks a `PreToolUse` action or a `Stop`; on `PostToolUse` the edit has already happened, and exit 2 feeds stderr back to the model.** A `PreToolUse` deny fires in every permission mode; a `Stop` hook can refuse to end the turn until a check passes (with a cap of eight consecutive blocks). Anthropic's own `ralph-loop` plugin is a Stop hook that re-feeds the prompt until a completion promise appears. A minimal gate that runs the architecture tests and the current slice's tests after every edit, and again before the agent is allowed to stop:

```json
{
  "hooks": {
    "PostToolUse": [{
      "matcher": "Edit|Write",
      "hooks": [{ "type": "command", "command": "${CLAUDE_PROJECT_DIR}/.claude/hooks/gate.sh" }]
    }],
    "Stop": [{
      "hooks": [{ "type": "command", "command": "${CLAUDE_PROJECT_DIR}/.claude/hooks/gate.sh" }]
    }]
  }
}
```

```sh
#!/usr/bin/env sh
# .claude/hooks/gate.sh — exit 2 with the failure text on stderr
cd "$CLAUDE_PROJECT_DIR" || exit 2
for p in tests/Architecture.Tests tests/Slice.Tests; do   # dotnet test takes one project at a time
  if ! out=$(dotnet test "$p" --nologo 2>&1); then
    printf '%s\n' "$out" | tail -40 >&2
    exit 2
  fi
done
```

(A Stop hook should also read the JSON on stdin and exit 0 when `stop_hook_active` is true, to avoid looping on itself.) The same shape works for a formatter, a linter, jscpd, or a PreToolUse script that refuses writes to `tests/` or `Migrations/` — Beck's "genie deleting tests" problem, solved by not letting it.

Other gates that make a slice's contract mechanical:

- **Coverage thresholds:** coverlet's `/p:Threshold=80` (per assembly), Jest's per-path `coverageThreshold` (which can demand 100% on a handlers directory), pytest-cov's `--cov-fail-under`.
- **Mutation score:** Stryker's `thresholds.break` fails the build when the score drops (StrykerJS 10, Stryker.NET 4.16) — catching an agent that "passes" by weakening assertions.
- **Snapshot/approval tests** of a handler's response for a fixed request (Verify for .NET, Jest snapshots, insta for Rust) pin the request-in/response-out contract as a committed file.
- **PR-side blast radius:** a `CODEOWNERS` line per slice folder (branch protection can require the owner's review) plus a Danger rule that fails a PR touching files outside the declared slice and the shared kernel, or exceeding a line count. This turns akka.net's "< 300 lines" prose into a gate.

### 7.4 A reference slice

"Just like a developer, we often have a reference slice." At Bogard's last company the reference architectures were "domain agnostic, customer agnostic" and "always kept up to date", so anyone asking how to build a slice could be pointed at one. For an agent the reference slice is doubly important: since the agent copies what it finds, the slice it copies is the specification. Anthropic's guidance says as much ("`HotDogWidget.php` is a good example. follow the pattern"); Thoughtworks' *anchoring coding agents to a reference application* (Assess, November 2025; not carried into the April 2026 edition) formalises it as a live, compilable reference exposed to the agent so it can "detect drift and propose repairs".

Scaffolding forms: a `dotnet new` item template that scaffolds a slice from the reference (`.template.config/template.json` with a `sourceName` to rename); a Claude Code skill whose `scripts/` scaffolder is executed rather than read; a Cursor rule pointing at `@slice-template.ts`. Whichever form, the rule is that the reference slice is the one file set you refactor *first* when conventions change — otherwise the agent will faithfully propagate the old ones.

### 7.5 Small tasks, fresh sessions, parallel worktrees

Bogard's recurring theme is "reducing the context from every single angle": smaller user stories, smaller tasks, smaller sessions. "One user story, one slice" was the rule for teams; "one task, one slice, one context window" is the rule for agents — the context is "thrown away at the end of the task." DORA's small-batches capability and METR's "large and complex repositories" factor are the same point from the research side.

In Claude Code this maps to: `/clear` between unrelated tasks; plan mode for the explore-and-plan phase, then a fresh session to implement the plan; subagents with their own context for research and review; and worktrees for parallelism — `claude --worktree <name>` gives each session its own checkout and branch and blocks edits to the main checkout, `/batch` fans a change out to 5–30 subagents each in its own worktree and pull request. A slice is the natural unit for a worktree: independent folders, independent tests, independent PRs.

One thing does not parallelise: **persistence**. Schema migrations and the model snapshot sit outside every slice, and two agents adding migrations on separate branches corrupt each other's snapshot (EF Core's documentation says to "coordinate in advance and avoid working concurrently on migrations"). Serialise migration work, or give it a person.

### 7.6 The scheduled dedup pass

Teams used to reserve "10% of the time, or Fridays" for refactoring; Bogard's version is a scheduled pass run by agents "but still also have the humans as well." The industrial precedent is OpenAI's background Codex tasks that "scan for deviations … and open targeted refactoring pull requests", most reviewable "in under a minute".

Detectors first, because an ungated agent will invent abstractions: jscpd 5 (Rust engine, `--threshold` fails the build, an `ai` reporter that cuts output tokens ~79%, an MCP server for agents), PMD CPD (C#, TypeScript, Python, Java; exit code 4 on duplicates), SonarQube's `duplicated_blocks` metric (≥100 identical tokens over ≥10 lines). Schedulers second: Claude Code Routines (a saved prompt run on a cron from the cloud, minimum interval one hour, opening `claude/`-prefixed branches), `claude-code-action@v1` on a GitHub Actions `schedule:`, or the DRYwall plugin (jscpd via MCP, a `/drywall:scan` command and a `dedup-refactor` subagent). A minimal weekly routine: run jscpd on `src/`; for each clone present in three or more slices, extract it to `Domain/` or `Platform/` *only if the logic is identical and stable*; run all tests and the architecture tests; open a PR. Two or fewer copies stay duplicated — Metz's rule, and Jovanović's rule of three.

No published case study yet reports outcomes from a scheduled agent dedup pass; treat it as Bogard's practice recommendation with a sound rationale, not a measured result.

Bogard closes the talk on Ian Cooper's reframing of the job (in Bogard's paraphrase): "the skill is now calibrating our certainty in the code and deciding how much of that code is necessary to read" — and slicing "reduces the amount of code that we need to read in order to produce a new slice." Every mechanism in this section exists to make that calibration cheap: a green architecture test and a green slice test are what let a reviewer, human or agent, read less.

---

## 8. The limits

The sceptical architect's case, with the rebuttal where there is one.

**8.1 There is no controlled evidence.** No study varies repository architecture as a treatment and measures agent pass rate, tokens per task, review time or defect rate. The closest results are proxies (files touched, lines changed, the SonarSource minimal pairs) and experience reports (Bogard, Stannard, Miller, Böckeler). The talk says "we've seen this with numbers" about unsupervised slicing but shows none; asked in the Q&A what metrics prove VSA's efficiency, Bogard answered "team velocity, defects, code quality metrics as objective criteria. We also use subjective criteria with the team" — practitioner metrics, not a study — and he says himself that AI adoption "is just not like a randomized treatment". What the guide can honestly claim: the mechanisms are real (context degrades with length; success falls with files touched; agents copy their surroundings), VSA plausibly improves the relevant quantities, and the experiment has not been run. Its shape exists — minimal-pair repositories, FeatBench-style feature tasks — and section 10 proposes it.

**8.2 The shared 5% is where the risk lives.** Bogard concedes "there's still going to be shared stuff … databases, domain models shared as well", and in the Q&A that "the domain model is shared (and should be)". The blast radius of a slice-local edit is bounded; the blast radius of an edit to a shared entity, the `DbContext`, a pipeline behaviour, or the auth policy is every slice that uses it — and that is where money, identity and persistence sit. Small slice diffs can give reviewers a false sense of safety. Rebuttal (Bogard's, from the Q&A): shared code is pulled "into a location that explicitly captures the intended blast radius", and he keeps "shared folders at various levels and axes" rather than one dump folder — so the architecture makes the distinction *visible*: an edit under a shared location is recognisably a different kind of change, and CODEOWNERS or Danger can route it to heavier review. Layered code offers no such signal because every change touches shared folders.

**8.3 Cross-cutting changes and cross-slice reads.** A renamed domain concept, a new auth requirement, or a logging policy touches every slice; with 60 slices that is 60 edit sites, and compound refactorings are what agents are worst at (SWE-Refactor, February 2026: an OpenAI Codex agent succeeded on 39.4% of compound instances). Reports and queries that join data owned by several use cases have no home in use-case slices; VSA does not answer data ownership, so the agent building `OverdueInvoicesByRegion` in one context window can duplicate three loaders, import three slices' internals, or build a projection; VSA's only rule is Bogard's Q&A answer — "move the shared logic to a location that reflects it is being intentionally shared" — which names the destination but not the ownership. Rebuttal: genuinely cross-cutting concerns live in one place by design (pipeline behaviours, middleware), fan-out tooling makes sweeps mechanical, shared-concept renames are rare relative to feature work, and the answers for reads are known — feature-specific read models with composition in one place (Dudycz), modules that own data (Jovanović). The honest conclusion is that VSA is the micro pattern and needs a macro one beside it.

**8.4 The argument is really about small, enforced, cohesive units.** Modular monoliths with verified boundaries (Spring Modulith's `verify()`, Nx tags, packwerk), hexagonal architecture with one input port per use case, and monorepo package boundaries all deliver "bounded context per change" and "bounded review" — and Bogard's own remedy, the architecture test, is exactly the kind of mechanical boundary he says interfaces are not. Matt Pocock's *How to make codebases AI agents love* takes the same premise ("your codebase … is the biggest influence on AI's output") to a different prescription: deep modules behind narrow interfaces, "you own the interface, AI owns the implementation, tests keep it honest." The frontend's mature slicing method, Feature-Sliced Design, reintroduces horizontal layers for shared entities and the UI kit — a sign that component-heavy SPA frontends need a shared layer beside the slices. Bogard's slides are API-only, though his sliced reference (ContosoUniversity) slices a server-rendered UI per page; the SPA case is the one his material does not address. VSA is also a poor fit where the cohesive unit is the rule rather than the request (pricing or eligibility engines; rich shared domains — where Jovanović still recommends layers), and for data and ML pipelines, whose communities converge on stage-based layouts and where entanglement means no folder boundary bounds a change. The fair framing of the thesis is *vertical, plus mechanically enforced boundaries*, not *slices versus clean*.

**8.5 Long context and retrieval may make structure matter less.** Vendors sell 1M-token windows as "entire codebases with over 75,000 lines of code" (Anthropic, August 2025). But Google's own Gemini 2.5 report shows long-context *reasoning* scores falling steeply between 128k and 1M tokens (its harder retrieval benchmark drops too), even though simple needle-in-a-haystack recall stays near-perfect; Augment's arithmetic puts about 2,000 files in a 200K-token window (roughly 10,000 in a 1M one) against a 400,000-file codebase; and Anthropic's Claude Code guidance treats the window as the resource to protect. The window is a ceiling, not a working set — Bogard anticipates this: agents "are definitely getting better and being able to look at larger and larger contexts. But … do they need to, should they have to?" What matters is signal density, which is a structural property. And as usable context grows (Epoch AI, June 2025: the input length at which top models reach 80% accuracy rose over 250× in the preceding nine months), the right bounded unit may move from use case to module; the principle survives, the calibration will not.

Retrieval is the stronger counter. Cursor's semantic search raised agent accuracy 12.5% on average, more on large codebases, and Claude Code navigates by grep and file names just-in-time — so an agent does not "load four files in four folders" eagerly the way the talk implies; it pays in search hops and distractors instead, which nobody has measured per architecture. Retrieval delivers part of guardrail 1 (less reading) without VSA; it delivers none of guardrail 2 (a bounded blast radius) or 3. Bogard's own Q&A answer to "why not ASTs and LSPs instead?" concedes the point and reframes it: "Perhaps, but why? VSA does this more easily and makes it inherent in the code instead of external in a tool."

**8.6 "Regenerate from what?" is weaker than it sounds.** Against "just regenerate" Bogard answers that agents "don't just invent something from whole cloth" — there is no spec to regenerate from, "the spec is now the code". That holds against vibe coding and against the observed reality that agent-written code is *modified less* than human code, not thrown away (Rahman and Shihab, January 2026: 16% lower hazard of modification). It does not hold against spec-driven development, where Kiro (July 2025), GitHub's spec-kit (131k stars by August 2026) and Sean Grove's argument that code is "a lossy projection from the specification" keep a maintained specification outside the code; Chad Fowler's *Regenerative Software* argues the durable assets are interfaces, behaviour and evaluations, and code is "meant to die". The camps converge more than they conflict: Fowler's "durable boundaries plus evaluations" is the slice boundary plus the handler test by another name, spec-kit's "constitution" and Kiro's steering files are rules-in-the-repo, and Thoughtworks warns that long generated specs "may be relearning a bitter lesson" about hand-crafted rules.

**8.7 Tests as back pressure have a price and a validity problem.** Handler tests are integration tests against a real database. In an agent loop that runs the suite many times per task, container start-up (tens of seconds cold) and output volume both slow the loop and consume the context budget, and parallel agents each need an isolated database. Rebuttal: slice-scoped tests are exactly what lets an agent run only its slice's tests (Anthropic's sample CLAUDE.md says "prefer running single tests"), and container reuse, Respawn and template databases make it tractable. The validity problem (5.3) is orthogonal to architecture but sharper under it: a test written in the same session as the handler shares its blind spots, so the second session, or the person, has to own the test.

**8.8 "An agent does not hesitate" is contested.** On 3,691 Multi-SWE-bench patches (*Refactoring Runaway*, May 2026) agents introduced tangled, out-of-scope refactorings *less* often than humans (21.43% vs 36.72%) and with lower intensity; on FeatBench (2025–2026) a prevalent failure pattern was "aggressive implementation" causing "scope creep and widespread regressions"; on merged PRs (MSR 2026) agents' code-generation changes broke less often than humans' (3.5% vs 7.4%), but their refactoring and chore PRs broke two to three times as often as their own code-generation PRs (6.7% and 9.4%). The safe statement is Bogard's own qualification sharpened: agents' scope discipline varies by task and model, so a bounded blast radius is insurance against the bad cases, not a response to a uniform trait.

---

## 9. A decision guide

The three guardrails are properties of *small, cohesive, mechanically bounded units of change*. VSA is the most direct way to get them for request/response systems; it is not the only way, and it is not free.

| VSA-for-agents pays off when | Think twice when |
|---|---|
| The system is request/response shaped — APIs, back-office web apps, message handlers — and most changes are "add or change a use case" | The cohesive unit is a rule set or a rich shared model that most use cases consult (pricing, eligibility, tax, rules engines) |
| Features are largely independent and vary in complexity, so a thin slice and a thick slice can each be what they need | The work is data or ML pipelines, where the unit of change is a transformation with many consumers |
| Agents are doing a large share of authoring and review is the bottleneck you feel | The UI dominates and needs shared entities, design system and state — use feature folders on the frontend, but expect layers |
| You are willing to write and keep the architecture tests, the handler tests and the rules file — the "mechanical" half | You already have verified module boundaries (modular monolith, Nx, packwerk); add slices *inside* modules rather than replacing the macro structure |
| Sessions can be one slice at a time and PRs can be slice-sized | Persistence changes are frequent and parallel — they need serialising regardless of architecture |

Whichever side you land on, four of Bogard's practices transfer to any architecture: one task per session, an enforced boundary rule, a behaviour test through the unit's entry point, and conventions in a rules file in the repository (which, per section 7.2, should be commands and constraints rather than descriptions). They are also the ones with the most direct evidence — session length (adherence decay), the boundary rule (Böckeler's dependency-cruiser observation), and instructions written as commands (the ETH finding that those are followed, even though context files as a whole did not raise success rates). None is a controlled result.

---

## 10. Applying it: a starter checklist and a prototype

For a new or newly sliced service, in the order that makes each step verifiable before the next:

1. **Lay out the slices.** `src/Features/<UseCase>/` (or `src/features/<use-case>/`) with request, response, validator, handler, endpoint mapping and test together; `src/Domain/` for shared entities, value objects and policies; `src/Platform/` for persistence, auth, logging and pipeline behaviours. No `Common/`, `Shared/` or `Helpers/`. Name slices as use cases (`CreateOrder`, `CancelOrder`), never as modules (`Orders`).
2. **Write the architecture test first** (7.1) — "slices do not depend on each other" — and run it in CI. It is a few lines in every ecosystem and it is the only rule the agent cannot argue with.
3. **Build one reference slice by hand**, complete with its test, and name it in the rules file. Refactor it first whenever a convention changes.
4. **Write the rules file** (7.2): under 200 lines; commands, constraints, the slice rules, the reference slice, and where the agent must stop and ask. Import it into every tool your team uses (`@AGENTS.md` from CLAUDE.md).
5. **Wire the gates** (7.3): a hook (exit code 2 on failure) or a CI step (any non-zero exit) that runs the architecture tests and the slice's tests; a PreToolUse guard on `tests/` and `Migrations/`; a coverage or mutation threshold on the handlers directory; CODEOWNERS per slice folder and a PR-size rule.
6. **Work one slice per session** (7.5): plan in one session, implement in a fresh one, review in a third (or a subagent with a clean context); worktree per slice for parallel work; migrations serialised.
7. **Schedule the dedup pass** (7.6): jscpd or CPD with a threshold in CI; a weekly agent routine that extracts only three-plus-slice, identical, stable duplication; a human reviews the PR.
8. **Measure what the talk does not.** Per PR: files touched, lines changed, tokens and turns to green, review time, incidents. Per month: duplicated blocks per thousand lines, architecture-test failures caught, migrations conflicts. These are the numbers that would turn the thesis into evidence.

**Prototype to build:** `prototypes/ai-development/vsa-agent-guardrails/` — a small .NET 10 Minimal API (three slices, a shared domain model, a Testcontainers database) laid out twice, once sliced and once layered, with identical behaviour and tests; the sliced copy carries the ArchUnitNET rule, the rules file, the hooks and a jscpd gate from this section. The experiment: give the same five feature tasks (three slice-local, one cross-cutting, one migration) to Claude Code against each copy, one task per session, and record files read, tokens, turns to green, architecture-test failures, and out-of-scope edits. It is the minimal-pair study for VSA that nobody has published, and it would also be the reference slice for anything built after it. Not started; listed under the topic's prototypes when it exists.

---

## 11. References

### The talk and Jimmy Bogard's writing

- Jimmy Bogard — *Vertical Slice Architecture: Effective Guardrails for AI Development* (Codeartify public video session, recorded 2026-08-20, published 2026-08-24): https://www.youtube.com/watch?v=vXQyMaSNrTw
- Codeartify — session page with the 17-question audience Q&A and links to the slide deck: https://codeartify.com/en/public-video-sessions/vertical-slice-architecture-effective-guardrails-for-ai-development
- Jimmy Bogard — *Vertical Slice Architecture Webinar* (announcement, 2026-07-23): https://www.jimmybogard.com/vertical-slice-architecture-webinar/
- Jimmy Bogard — *Vertical Slice Architecture* (the naming post, 2018-04-19): https://www.jimmybogard.com/vertical-slice-architecture/
- Jimmy Bogard — *Vertical Slice Architecture* (NDC Sydney 2018 recording): https://www.youtube.com/watch?v=SUiWfhAhgQw
- Jimmy Bogard — *SOLID Architecture in Slices not Layers* (NDC Oslo 2015): https://av.tib.eu/media/50483
- Tim G. Thomas — *Feature Folders in ASP.NET MVC* (2013-10-03, the earliest documented form): https://timgthomas.com/2013/10/feature-folders-in-asp-net-mvc/
- Jimmy Bogard — *AutoMapper and MediatR Commercial Editions Launch Today* (2025-07-02): https://www.jimmybogard.com/automapper-and-mediatr-commercial-editions-launch-today/

### Vertical Slice Architecture: the wider discussion

- Milan Jovanović — *Vertical Slice Architecture: Where Does the Shared Logic Live?* (2025-11-29; source of "removes the guardrails"): https://milanjovanovic.tech/blog/vertical-slice-architecture-where-does-the-shared-logic-live
- Milan Jovanović — *How to Test Vertical Slice Architecture* (2026-07-11; "tests coupled to layers punish refactoring"): https://milanjovanovic.tech/blog/how-to-test-vertical-slice-architecture
- Milan Jovanović — *Vertical Slice Architecture vs Clean Architecture* (2026-08-13): https://milanjovanovic.tech/blog/vertical-slice-vs-clean-architecture
- Milan Jovanović — *When to Choose Vertical Slice Architecture* (2026-08-13): https://milanjovanovic.tech/blog/when-to-choose-vertical-slice-architecture
- Milan Jovanović — *Where Vertical Slices Fit Inside the Modular Monolith Architecture* (2026-02-21): https://milanjovanovic.tech/blog/where-vertical-slices-fit-inside-the-modular-monolith-architecture
- Derek Comartin — *Vertical Slice Architecture Myths You Need To Know!* (2024-04-24): https://codeopinion.com/vertical-slice-architecture-myths-you-need-to-know/
- Oskar Dudycz — *My thoughts on Vertical Slices, CQRS, Semantic Diffusion and other fancy words* (2025-08-25): https://www.architecture-weekly.com/p/my-thoughts-on-vertical-slices-cqrs
- Oskar Dudycz — *Vertical slices, their ownership and external dependencies* (2026-08-10): https://www.architecture-weekly.com/p/vertical-slices-their-ownership-and
- Oskar Dudycz — *Fractal Architecture, Cognitive Load, Vertical Slices and other terms that do(n't) fit your head* (2026-08-17): https://www.architecture-weekly.com/p/fractal-architecture-cognitive-load
- Anton Martyniuk — *How to Avoid Code Duplication in Vertical Slice Architecture in .NET* (2026-02-24): https://antondevtips.com/blog/how-to-avoid-code-duplication-in-vertical-slice-architecture-in-dotnet
- Jeremy D. Miller — *The Codebase Is the Prompt: Wolverine, Vertical Slices, and AI-Assisted Development* (2026-06-04): https://jeremydmiller.com/2026/06/04/the-codebase-is-the-prompt-wolverine-vertical-slices-and-ai-assisted-development/
- Steve Smith — *MVC Controllers are Dinosaurs - Embrace API Endpoints* (REPR, 2021-01-20): https://ardalis.com/mvc-controllers-are-dinosaurs-embrace-api-endpoints/
- Feature-Sliced Design — overview (a different, layered methodology): https://feature-sliced.design/docs/get-started/overview
- Sandi Metz — *The Wrong Abstraction* (2016-01-20): https://sandimetz.com/blog/2016/1/20/the-wrong-abstraction
- Matt Pocock — *How To Make Codebases AI Agents Love* (deep modules, the friendly counter-position): https://www.aihero.dev/how-to-make-codebases-ai-agents-love

### Practitioners on AI-assisted development

- Kent Beck — *Constantine's Equivalence* (2022-08-15; the "cost of software ≈ cost of change" line, ch. 30 of *Tidy First?*): https://newsletter.kentbeck.com/p/constantines-equivalence
- Ian Cooper — *Is AI a Silver Bullet?* (2024-06-24): https://ian-cooper.writeas.com/is-ai-a-silver-bullet
- Ian Cooper — *Coding Agents: Driving In Gears* (2026-07-10; "the skill is calibrating our certainty"): https://ian-cooper.writeas.com/coding-agents-and-driving-in-gears
- David Whitney — *The Programmer's Guide to Co-Designing with Agents* (2026-03-11): https://davidwhitney.co.uk/blog/2026/03/11/co_design_with_agents/
- David Whitney — *Context Transference* (2025-05-30): https://davidwhitney.co.uk/blog/2025/05/30/context_transference
- Aaron Stannard — *Software 2.0: Code is Cheap, Good Taste is Not* (2026-01-26): https://aaronstannard.com/beginning-of-software-2.0/
- Aaron Stannard — *Software 2.0: Planning and Verifying a Greenfield Project* (2026-03-13): https://aaronstannard.com/software-2.0-case-study-textforge/
- Geoffrey Huntley — *the six-month recap* (2025-06-17; "applies pressure to the generative loop"): https://ghuntley.com/six-month-recap/
- Geoffrey Huntley — *Ralph Wiggum as a "software engineer"* (2025-07-14): https://ghuntley.com/ralph/
- Kent Beck — *The Genie Eats The Seed Corn* (2025-05-03) and *Augmented Coding: Beyond the Vibes* (2025-06-25): https://newsletter.kentbeck.com/p/augmented-coding-and-design and https://newsletter.kentbeck.com/p/augmented-coding-beyond-the-vibes
- Simon Willison — *Context engineering* (2025-06-27) and *Vibe engineering* (2025-10-07): https://simonwillison.net/2025/Jun/27/context-engineering/ and https://simonwillison.net/2025/Oct/7/vibe-engineering/
- Simon Willison — *Context rot* (2025-06-18; the coining on Hacker News): https://simonwillison.net/2025/Jun/18/context-rot/
- Addy Osmani — *The 70% problem: Hard truths about AI-assisted coding* (2024-12-04): https://addyo.substack.com/p/the-70-problem-hard-truths-about
- Birgitta Böckeler — *Harness engineering for coding agent users* (2026-04-02) and *Maintainability sensors for coding agents* (2026-05-27): https://martinfowler.com/articles/harness-engineering.html and https://martinfowler.com/articles/sensors-for-coding-agents.html
- Chad Fowler — *Regenerative Software* (2025-12-21): https://aicoding.leaflet.pub/3majnyfydzs2y
- Martin Fowler — *Mocks Aren't Stubs* (2004): https://martinfowler.com/articles/mocksArentStubs.html
- Ian Cooper — *TDD, Where Did It All Go Wrong* (DevTernity, 2017): https://www.youtube.com/watch?v=EZ05e7EMOLM

### Vendor engineering guidance and tool documentation

- Anthropic — *Effective context engineering for AI agents* (2025-09-29): https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents
- Claude Code — best practices, memory (CLAUDE.md and rules), hooks, subagents, worktrees, routines, GitHub Actions, costs: https://code.claude.com/docs/en/best-practices, https://code.claude.com/docs/en/memory, https://code.claude.com/docs/en/hooks, https://code.claude.com/docs/en/sub-agents, https://code.claude.com/docs/en/worktrees, https://code.claude.com/docs/en/routines, https://code.claude.com/docs/en/github-actions, https://code.claude.com/docs/en/costs
- Anthropic — `ralph-loop` plugin (a Stop-hook implementation of the loop): https://github.com/anthropics/claude-plugins-official/tree/main/plugins/ralph-loop
- OpenAI — *Harness engineering: leveraging Codex in an agent-first world* (February 2026): https://openai.com/index/harness-engineering/
- AGENTS.md — the convention: https://agents.md/ ; Linux Foundation — Agentic AI Foundation announcement (2025-12-09): https://www.linuxfoundation.org/press/linux-foundation-announces-the-formation-of-the-agentic-ai-foundation
- Cursor — rules: https://cursor.com/docs/context/rules ; GitHub Copilot — repository custom instructions: https://docs.github.com/en/copilot/how-tos/configure-custom-instructions/add-repository-instructions
- Cursor — *Improving agent with semantic search* (2025-11-06): https://cursor.com/blog/semsearch
- Anthropic — *Claude Sonnet 4 now supports 1M tokens of context* (2025-08-12): https://claude.com/blog/1m-context
- Thoughtworks Technology Radar — *Curated shared instructions for software teams*, *Anchoring coding agents to a reference application*, *AI-friendly code design*, *Ralph loop*, *Spec-driven development*: https://www.thoughtworks.com/radar/techniques/curated-shared-instructions-for-software-teams, https://www.thoughtworks.com/radar/techniques/anchoring-coding-agents-to-a-reference-application, https://www.thoughtworks.com/radar/techniques/ai-friendly-code-design, https://www.thoughtworks.com/radar/techniques/ralph-loop, https://www.thoughtworks.com/radar/techniques/spec-driven-development
- Kiro — specs and steering files: https://kiro.dev/docs/specs/ ; GitHub — spec-kit: https://github.com/github/spec-kit
- Microsoft Learn — *Migrations in Team Environments* (EF Core): https://learn.microsoft.com/en-us/ef/core/managing-schemas/migrations/teams
- GitHub Docs — *About code owners*: https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/about-code-owners ; Danger JS: https://danger.systems/js/

### Reports and surveys

- Stack Overflow — 2025 Developer Survey, AI section (2025-07-29): https://survey.stackoverflow.co/2025/ai
- Faros AI — *AI Engineering Report 2026: The Acceleration Whiplash* (April 2026): https://www.faros.ai/research/ai-acceleration-whiplash
- Faros AI — *The AI Productivity Paradox* (July 2025): https://www.faros.ai/blog/ai-software-engineering
- GitClear — *The Maintainability Gap: AI Code Quality in 2026*: https://www.gitclear.com/the_ai_code_quality_maintainability_gap
- GitClear — *AI Copilot Code Quality: 2025 Data Suggests 4x Growth in Code Clones* (February 2025): https://www.gitclear.com/ai_assistant_code_quality_2025_research
- DORA — *State of AI-assisted Software Development 2025* (2025-09-23) and the announcement post: https://dora.dev/research/2025/dora-report/ and https://cloud.google.com/blog/products/ai-machine-learning/announcing-the-2025-dora-report
- DORA — *Accelerate State of DevOps Report 2024*: https://dora.dev/research/2024/dora-report/
- DORA — *AI Capabilities Model* (2025): https://dora.dev/ai/capabilities-model/report/
- METR — *Measuring the Impact of Early-2025 AI on Experienced Open-Source Developer Productivity* (2025-07-10) and the February 2026 update: https://metr.org/blog/2025-07-10-early-2025-ai-experienced-os-dev-study/ and https://metr.org/blog/2026-02-24-uplift-update/
- Chroma — *Context Rot: How Increasing Input Tokens Impacts LLM Performance* (2025-07-14): https://www.trychroma.com/research/context-rot
- Epoch AI — *LLMs now accept longer inputs, and the best models can use them more effectively* (2025-06-25): https://epoch.ai/data-insights/context-windows
- SmartBear — *Best Practices for Peer Code Review* (the Cisco study): https://smartbear.com/learn/code-review/best-practices-for-peer-code-review/
- Sadowski et al. — *Modern Code Review: A Case Study at Google* (ICSE-SEIP 2018): https://research.google/pubs/modern-code-review-a-case-study-at-google/

### Papers

- Zhang et al. — *SWE-bench Goes Live!* (arXiv:2505.23419, 2025; success vs files touched): https://arxiv.org/abs/2505.23419
- Scale AI — *SWE-Bench Pro* (arXiv:2509.16941, 2025): https://arxiv.org/abs/2509.16941
- *RepoRescue* (arXiv:2607.01213, 2026; the coordination cliff): https://arxiv.org/abs/2607.01213
- Trivedi and Schmitt (SonarSource) — *Does Code Cleanliness Affect Coding Agents? A Controlled Minimal-Pair Study* (arXiv:2605.20049, 2026): https://arxiv.org/abs/2605.20049
- Zhu et al. — *Needle in the Repo: A Benchmark for Maintainability in AI-Generated Repository Edits* (arXiv:2603.27745, 2026): https://arxiv.org/abs/2603.27745
- Dipongkor et al. — *Test Coverage Analysis of Agentic Pull Requests* (arXiv:2607.18057, 2026): https://arxiv.org/abs/2607.18057
- Xue et al. — *SWE-NFI: Benchmarking Coding Agents for Non-Functional Improvements* (arXiv:2607.27409, 2026): https://arxiv.org/abs/2607.27409
- Horikawa et al. — *Agentic Refactoring: An Empirical Study of AI Coding Agents* (arXiv:2511.04824, 2025): https://arxiv.org/abs/2511.04824
- Tian et al. — *"Refactoring Runaway": Understanding and Mitigating Tangled Refactorings in Coding Agents for Issue Resolution* (arXiv:2605.22526, 2026): https://arxiv.org/abs/2605.22526
- Chen, Li, Li — *FeatBench* (arXiv:2509.22237, 2025–2026): https://arxiv.org/abs/2509.22237
- Ferdous et al. — *Safer Builders, Risky Maintainers: Breaking Changes in Human vs Agentic PRs* (arXiv:2603.27524, MSR 2026): https://arxiv.org/abs/2603.27524
- *SlopCodeBench* (arXiv:2603.24755, 2026; erosion over iterations): https://arxiv.org/abs/2603.24755
- *SWE-Refactor* (arXiv:2602.03712, 2026; compound refactorings): https://arxiv.org/abs/2602.03712
- Hu et al. — *CLI-Tool-Bench* (arXiv:2604.06742, 2026; monolithic tendency): https://arxiv.org/abs/2604.06742
- Zhu, Tsantalis, Rigby — *AI-Generated Smells* (arXiv:2605.02741, 2026; the "modular mirage"): https://arxiv.org/abs/2605.02741
- Gloaguen et al. (ETH Zurich) — *Evaluating AGENTS.md: Are Repository-Level Context Files Helpful for Coding Agents?* (arXiv:2602.11988, 2026): https://arxiv.org/abs/2602.11988
- McMillan — *Instruction Adherence in Coding Agent Configuration Files: A Factorial Study* (arXiv:2605.10039, 2026): https://arxiv.org/abs/2605.10039
- Chatlatanagulchai et al. — *Agent READMEs: An Empirical Study of Context Files for Agentic Coding* (arXiv:2511.12884, 2025–2026): https://arxiv.org/abs/2511.12884
- Gao and Chen — *From Agent Behaviour to Agent-Friendly Documentation* (arXiv:2608.20195, 2026): https://arxiv.org/abs/2608.20195
- Rahman and Shihab — *Will It Survive? Deciphering the Fate of AI-Generated Code in Open Source* (arXiv:2601.16809, 2026): https://arxiv.org/abs/2601.16809
- Panickssery, Bowman, Feng — *LLM Evaluators Recognize and Favor Their Own Generations* (arXiv:2404.13076, 2024): https://arxiv.org/abs/2404.13076
- Huang et al. — *Large Language Models Cannot Self-Correct Reasoning Yet* (arXiv:2310.01798, 2023): https://arxiv.org/abs/2310.01798
- Jesse et al. — *Large Language Models and Simple, Stupid Bugs* (arXiv:2303.11455, 2023): https://arxiv.org/abs/2303.11455
- Pearce et al. — *Asleep at the Keyboard? Assessing the Security of GitHub Copilot's Code Contributions* (arXiv:2108.09293, 2021): https://arxiv.org/abs/2108.09293
- Liu et al. — *Lost in the Middle* (arXiv:2307.03172, TACL 2024): https://arxiv.org/abs/2307.03172
- *NoLiMa: Long-Context Evaluation Beyond Literal Matching* (arXiv:2502.05167, ICML 2025): https://arxiv.org/abs/2502.05167
- *LongCodeBench: Evaluating Coding LLMs at 1M Context Windows* (arXiv:2505.07897, COLM 2025): https://arxiv.org/abs/2505.07897
- Google — *Gemini 2.5* technical report (arXiv:2507.06261, 2025; long-context table): https://arxiv.org/abs/2507.06261
- Sculley et al. — *Hidden Technical Debt in Machine Learning Systems* (NeurIPS 2015): https://papers.nips.cc/paper/2015/hash/86df7dcfd896fcaf2674f757a2463eba-Abstract.html
- Foote and Yoder — *Big Ball of Mud* (1997): http://www.laputan.org/mud/

### Tools

- ArchUnitNET: https://archunitnet.readthedocs.io/en/latest/guide/ ; NetArchTest.eNhancedEdition: https://github.com/NeVeSpl/NetArchTest.eNhancedEdition ; ArchUnit (Java) slices: https://www.archunit.org/userguide/html/000_Index.html#_slices
- dependency-cruiser rules reference: https://github.com/sverweij/dependency-cruiser/blob/main/doc/rules-reference.md ; eslint-plugin-boundaries: https://www.jsboundaries.dev/docs/rules/dependencies/ ; Nx module boundaries: https://nx.dev/docs/features/enforce-module-boundaries ; Sheriff: https://sheriff.softarc.io/docs/dependency-rules
- import-linter independence contract: https://import-linter.readthedocs.io/en/stable/contract_types/independence/ ; tach: https://github.com/gauge-sh/tach
- go-arch-lint: https://github.com/fe3dback/go-arch-lint ; Go internal packages: https://go.dev/doc/go1.4#internalpackages
- Spring Modulith verification: https://docs.spring.io/spring-modulith/reference/verification.html ; packwerk (Shopify): https://shopify.engineering/enforcing-modularity-rails-apps-packwerk
- jscpd: https://github.com/kucherenko/jscpd ; PMD CPD: https://docs.pmd-code.org/latest/pmd_userdocs_cpd.html ; SonarQube duplication metrics: https://docs.sonarsource.com/sonarqube-server/user-guide/code-metrics/metrics-definition ; DRYwall: https://github.com/nikhaldi/drywall
- Stryker (mutation testing) configuration: https://stryker-mutator.io/docs/stryker-net/configuration/ ; coverlet thresholds: https://github.com/coverlet-coverage/coverlet/blob/master/Documentation/MSBuildIntegration.md ; Jest `coverageThreshold`: https://jestjs.io/docs/configuration#coveragethreshold-object
- Verify (approval tests for .NET): https://github.com/VerifyTests/Verify ; Testcontainers reuse: https://rieckpil.de/reuse-containers-with-testcontainers-for-fast-integration-tests/ ; Respawn: https://github.com/jbogard/Respawn
- .NET custom templates (`dotnet new`): https://learn.microsoft.com/en-us/dotnet/core/tools/custom-templates

### Example repositories and rules files

- jbogard/ContosoUniversityDotNetCore-Pages (the sliced reference; `Pages/Students/`, `IntegrationTests/SliceFixture.cs`): https://github.com/jbogard/ContosoUniversityDotNetCore-Pages
- jbogard/eShop, branch `vsa/start` (Bogard's sliced fork of Microsoft's eShop): https://github.com/jbogard/eShop ; dotnet/eShop (the layered original): https://github.com/dotnet/eShop
- SSWConsulting/SSW.VerticalSliceArchitecture (.NET 10, FastEndpoints, NetArchTest architecture tests): https://github.com/SSWConsulting/SSW.VerticalSliceArchitecture
- nadirbad/VerticalSliceArchitecture (.NET 10, MediatR, one static class per use case): https://github.com/nadirbad/VerticalSliceArchitecture
- jasontaylordev/CleanArchitecture (the layered contrast): https://github.com/jasontaylordev/CleanArchitecture
- akkadotnet/akka.net AGENTS.md (Bogard's example of conventions in agent files): https://github.com/akkadotnet/akka.net/blob/dev/AGENTS.md
- mryll/skills — vertical-slice-architecture (language-agnostic rules for agents): https://github.com/mryll/skills/blob/main/skills/vertical-slice-architecture/SKILL.md
- codewithmukesh/dotnet-claude-kit — vertical-slice skill and CLAUDE.md templates: https://github.com/codewithmukesh/dotnet-claude-kit
- Vladyslav Furdak — *Vertical Slice Architecture for Claude Code: dotnet-vsa-webapi Explained* (2026-03-16): https://www.furdak.net/articles/dotnet-vsa-webapi-skill
- Wolverine — Vertical Slice Architecture tutorial: https://wolverinefx.net/tutorials/vertical-slice-architecture.html ; FastEndpoints: https://fast-endpoints.com/
- Oskar Dudycz — *How to slice the codebase effectively?* (2021-09-08; gerund-named operation folders): https://event-driven.io/en/how_to_slice_the_codebase_effectively/
- Petar Ivanov — *Vertical Slice Architecture in Node.js: One Folder Per Use Case* (2026-04-11): https://thetshaped.dev/p/vertical-slice-architecture-in-nodejs-typescript-one-folder-per-use-case

---

*Compiled from the talk's full transcript and a multi-agent research sweep (6 research agents, 3 adversarial fact-checkers, 1 completeness critic; ~1,050 source fetches) on 2026-08-26. Statistics were verified against the primary reports at that date and several of the talk's figures and attributions are corrected above; expect the tool versions and the long-context numbers to drift first.*
