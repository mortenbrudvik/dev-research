---
title: The Second Brain and AI
description: What a second brain was meant to be, the three things large language models change about it, which memory architectures hold up at personal scale, what the evidence says about offloading thinking to a tool, and how to build one that serves both you and your agents.
status: draft
tags: [ai, agents, memory, knowledge-management, context-engineering]
---

# The Second Brain and AI

*What a second brain was meant to be, the three things large language models change about it, which memory architectures hold up at personal scale, what the evidence says about offloading thinking to a tool, and how to build one that serves both you and your agents.*

**Status:** draft as of September 2026 — compiled from a four-agent research sweep on 2 September 2026 and not yet reviewed by the owner. Product detail in this space changes monthly; every dated claim is sourced in [References](#8-references), and the argument does not depend on any single product surviving.

---

## Table of contents

1. [The question](#1-the-question)
2. [What a second brain was supposed to be](#2-what-a-second-brain-was-supposed-to-be)
3. [Three things language models change](#3-three-things-language-models-change)
4. [Memory architectures at personal scale](#4-memory-architectures-at-personal-scale)
5. [The landscape in 2026](#5-the-landscape-in-2026)
6. [What the evidence says](#6-what-the-evidence-says)
7. [Building one](#7-building-one)
8. [References](#8-references)

---

## 1. The question

"Second brain" is an eighty-year-old idea with a new tenant. Vannevar Bush described the device in 1945, Niklas Luhmann ran one on paper for thirty years, and Tiago Forte turned it into a course, a book and a movement between 2017 and 2022. Every version put the value in the same place: not in storing things, but in the associations between them and in the thinking the store provokes.

Then the reader changed. A note written in 2026 has two audiences — the person who wrote it and the language model that will be handed it as context — and the second audience does not need the folders, the highlights or the summaries that the first one spent years maintaining. At the same time, the maintenance itself became cheap: an agent can file, link, summarise and cross-reference a corpus faster than its owner can read it. Forte's own reaction to this was to stop teaching his method and rebrand the field, from Personal Knowledge Management to "Personal Context Management".

The question this guide answers is therefore not "which note app". It is: **what does a large language model change about the second brain, what survives the change, and what should a developer build given the evidence?** Three parts:

- what the concept was for, so that the changes can be measured against it (section 2);
- what actually changes, in retrieval, in readership and in maintenance (section 3), and which memory architectures hold up at the scale of one person's corpus (sections 4 and 5);
- what the research says about offloading memory and thinking to a tool — much of the popular evidence does not survive scrutiny, and the part that does is specific about when AI harms learning and when it does not (section 6).

Section 7 turns that into a layered design that serves a human reader and an agent at the same time, and notes that this repository already follows most of it.

## 2. What a second brain was supposed to be

The lineage is short and unusually consistent. Each step is listed with what it added and, more importantly, where it located the value.

| Year | Work | What it added | Where the value was |
|---|---|---|---|
| 1945 | Vannevar Bush, *As We May Think* | The memex: a personal store of "all his books, records, and communications", consulted "with exceeding speed and flexibility" | Association. "The process of tying two items together is the important thing." Trails persist and can be handed to others. |
| 1962 | Douglas Engelbart, *Augmenting Human Intellect* | The unit of analysis is the human plus artifacts, language, methodology and training, as one system | Augmentation of a whole system, not automation of a part |
| 1981 | Niklas Luhmann, *Communicating with Slip Boxes* | A Zettelkasten of fixed-address cards, linked freely, no topical hierarchy | A "second memory, an alter ego with which you can always communicate" — and only after "a couple of years" of feeding does it stop being "a container from which you get what you put in" |
| 1998 | Andy Clark and David Chalmers, *The Extended Mind* | The parity principle: an external artifact can be part of a cognitive process | Only under tight coupling — four conditions, below |
| 2017 | Sönke Ahrens, *How to Take Smart Notes* | Luhmann's method for the Roam and Obsidian era | "Writing is not what follows research, learning or studying, it is the medium of all this work." |
| 2017–2022 | Tiago Forte, *Building a Second Brain* | CODE (Capture, Organize, Distill, Express) and PARA (Projects, Areas, Resources, Archives); "organize by actionability" | "Our brains are for having ideas, not storing them." The Distill and Express steps are where the return is. |
| 2019– | Andy Matuschak, evergreen notes | Atomic, concept-oriented, densely linked notes written for one's future self | "Most 'storage-oriented' notes will never be useful again." The writing is the thinking. |

Two of these deserve a closer look, because the rest of the guide leans on them.

**The extended-mind test.** Clark and Chalmers' thought experiment has Otto, who has Alzheimer's, carrying a notebook that plays the role biological memory plays for Inga. They are careful about when that claim holds: the notebook must be "a constant in Otto's life", its information "directly available without difficulty", "automatically endorsed" on retrieval, and "consciously endorsed at some point in the past". Read as an engineering specification, those four conditions are a test most personal knowledge systems fail. A vault that is never consulted violates the first two; a vault whose contents the owner no longer trusts violates the third. Section 7 applies the same test to a vault that an agent maintains, where the third condition is exactly what hallucination and silent drift attack.

**Forte's CODE, split in two.** Capture and Organize are storage operations: they decide what enters the system and where it sits. Distill and Express are thinking operations: progressive summarisation ("you cannot compress something without losing some of its context", Forte concedes) and producing something with the result. Forte's own definition of a second brain — "an external, centralized, digital repository for the things you learn and the resources from which they come" — describes the storage half, and the pre-AI critiques of the movement all attack systems that stop there.

Those critiques predate ChatGPT and are worth listing because AI amplifies every one of them:

- **The collector's fallacy.** Christian Tietze, 2014: "'to know about something' isn't the same as 'knowing something'"; collecting produces "the illusion of having read the text already".
- **Notes as anxiety management.** Daniel Wentsch, October 2025, after 4,000 notes across five apps: "I wasn't thinking anymore. I was categorizing." Sasha Chapin, 2022: a system with no context of use means "you're LARPing".
- **The mausoleum.** Joan Westenberg deleted 10,000 notes and seven years of Obsidian in July 2025: "Instead of accelerating my thinking, it began to replace it." Reagan Rose, 2023, on the connected-notes apps: "Cognition precedes keystroke."
- **Matuschak's own meta-critique.** "People who write extensively about note-writing rarely have a serious context of use", and "the most effective readers and thinkers I know don't take notes when reading". Luhmann barely wrote about his Zettelkasten; he wrote fifty-odd books with it.

The pattern in all of them: the value was always in the associating and the thinking, and a system optimised for capture and filing produces a store without a mind attached. Keep that in view, because the first thing language models do is make capture and filing free.

## 3. Three things language models change

### 3.1 Retrieval no longer needs your structure

Folders, tags and PARA exist because keyword search was bad at finding a note you half remember. Embedding search is not, and the vendors noticed first. Mem's guide "Your notes are a mess. That's fine." argues that filing was an "organizing tax" imposed by dumb search and that with semantic retrieval plus proactive resurfacing you should capture aggressively and never file. Every AI note product in section 5 makes some version of this promise, and the well-read practitioner posts of 2026 describe agents re-filing thousands of notes over a couple of sessions.

Two qualifications survive contact with the evidence. First, retrieval quality has hard limits at personal scale — chunk boundaries lose context, multi-hop and temporal questions fail, and a corpus has no "sense of the whole" without added structure (section 4). Second, PARA's "organize by actionability" was never only a retrieval scheme. A Projects folder is a statement of what its owner is committed to right now; Forte's twelve favourite problems are a filter for what is worth keeping at all. Those are decisions about attention, and a model cannot make them on the owner's behalf without being told. Which is the second change.

### 3.2 The reader is now a model

In March 2026 Forte published "Introducing The AI Second Brain", in which he says ChatGPT's release made his methods feel "obsolete" and that he stopped teaching because he "could no longer authentically continue to teach the same methods". His replacement thesis, in his words: "Personal Context Management is replacing Personal Knowledge Management", because "the new bottleneck isn't AI capability, but your ability to give AI the right information at the right time", and "your personal notes and files are about to become your most valuable professional asset". Four months later, reviewing a capture tool, he put the consequence plainly: notes "are no longer just for you. They're inputs to a system that can act on your behalf."

Engineers had reached the same conclusion from the other side and named it a year earlier. Tobi Lütke, June 2025: context engineering is "the art of providing all the context for the task to be plausibly solvable by the LLM". Karpathy, a week later: "+1 for 'context engineering' over 'prompt engineering' … the delicate art and science of filling the context window with just the right information for the next step." Anthropic's September 2025 guide defines it as "curating and maintaining the optimal set of tokens (information) during LLM inference", warns about the finite attention budget and context rot, and recommends just-in-time retrieval through "lightweight identifiers (file paths, stored queries, web links, etc.)" over dumping everything in up front.

Coding agents are the proof that this is not a metaphor. A developer's second brain for an agent already exists and is versioned in the repository:

- **A human-written layer**: `CLAUDE.md`, `AGENTS.md`, Cursor rules, Copilot instructions. Stable knowledge — commands, conventions, gotchas — loaded at the start of every session. AGENTS.md went from five vendors in August 2025 to more than 60,000 projects and a Linux Foundation home by December.
- **An agent-written layer**: Claude Code's auto memory writes notes typed `user`, `feedback`, `project` and `reference` into a per-repository directory with a `MEMORY.md` index of one line per note; the index loads at start and topic files are read on demand. Cursor's Memories do the same with sentence-sized facts. Anthropic's description of Claude Code is the hybrid in one sentence: "CLAUDE.md files are naively dropped into context up front, while primitives like glob and grep allow it to navigate its environment and retrieve files just-in-time."

That is Bush's memex with the roles reassigned: the human curates the trails, the model walks them. It is also exactly the structure Karpathy proposed for personal knowledge, which is the third change.

### 3.3 Maintenance is cheap

Luhmann's warning was that a Zettelkasten "needs a couple of years to reach critical mass". Most of that time went into the bookkeeping — summarising, cross-referencing, filing — and it is that bookkeeping that agents remove.

The cleanest statement is Karpathy's "LLM Wiki" idea file, published as a gist on 4 April 2026 after an X post in which he said most of his recent token budget went into "manipulating knowledge" rather than code, and that one topic had reached about 100 articles and 400,000 words. The gist is written to be pasted into an agent and is "intentionally abstract". Its argument against retrieval-augmented generation: "Instead of just retrieving from raw documents at query time, the LLM incrementally builds and maintains a persistent wiki … The knowledge is compiled once and then kept current, not re-derived on every query." The structure has three layers and three operations:

- **Raw sources**, "immutable — the LLM reads from them but never modifies them".
- **The wiki**, a directory of LLM-generated markdown. "The LLM owns this layer entirely."
- **The schema**, a document that "tells the LLM how the wiki is structured, what the conventions are, and what workflows to follow" — in practice a `CLAUDE.md` or `AGENTS.md`.
- **Ingest**: read a source, discuss it, write a summary page, update the index and every affected entity and concept page, append to a log. "A single source might touch 10-15 wiki pages."
- **Query**: search the wiki, answer with citations, and file good answers back as new pages.
- **Lint**: periodically look for "contradictions between pages, stale claims that newer sources have superseded, orphan pages with no inbound links, important concepts mentioned but lacking their own page, missing cross-references, data gaps".

The division of labour: "You're in charge of sourcing, exploration, and asking the right questions. The LLM does all the grunt work." And the working setup: "Obsidian is the IDE; the LLM is the programmer; the wiki is the codebase."

The same move appears elsewhere under other names. Microsoft's GraphRAG (2024) has a model extract entities and relations, cluster them into communities and write a summary per community; those summaries are machine-generated hub pages, produced statistically rather than by an agent following a schema. Letta's "sleep-time compute" (April 2025) has a second agent rewrite the primary agent's memory between turns, turning "raw context" into "learned context" — Karpathy's lint pass as infrastructure. Cognition's DeepWiki (April 2025) does it for code: a wiki per repository that its agent reads instead of raw source.

What none of this changes is the part the critics in section 2 cared about. An agent can compile a wiki; it cannot do the owner's understanding for them, and section 6 shows what happens to the owner when it tries.

## 4. Memory architectures at personal scale

"Personal scale" means somewhere between a few hundred notes and a few hundred thousand tokens of source material — large enough that the choice of mechanism matters, small enough that the big-corpus assumptions of enterprise search do not hold. Five approaches are in use, and they are layers more than rivals.

| Approach | What it adds | Where it breaks | Cost profile |
|---|---|---|---|
| Full context | Nothing to index; the model sees everything | Context rot above tens of thousands of tokens; "lost in the middle" | Tokens per query scale with the corpus; prompt caching makes it cheap to repeat |
| Retrieval (RAG) | Only relevant chunks reach the model | Chunk boundaries lose context; multi-hop and temporal questions; no view of the whole | Cheap per query; quality depends on chunking, hybrid search and reranking |
| Knowledge graph | Entities, relations, community summaries; temporal validity | Expensive indexing; extraction errors compound | LLM-heavy at index time; LazyGraphRAG cuts that to vector-RAG levels |
| LLM-maintained wiki | Synthesis compiled once, cross-references and contradictions already handled | Errors embed permanently without lint; needs a human in the loop | Ingest cost per source; queries are cheap reads |
| Agent memory systems | Facts extracted from interaction, updated or invalidated on conflict | Extraction misses nuance; vendor benchmarks are contested | Per-turn extraction calls; small token footprint at query time |

**Full context is the right default below a threshold.** Anthropic's contextual-retrieval post says that under roughly 200,000 tokens — about 500 pages — the corpus should go in the prompt with caching and retrieval should be skipped. Above that, the evidence turns. Liu et al. (2023) documented the U-shaped "lost in the middle" curve; Chroma's "Context Rot" study of 18 models (July 2025) found performance "consistently degrades with increasing input length" even on simple tasks, and on the LongMemEval benchmark a focused context of about 300 tokens beat the full 113,000-token history for every model tested. Databricks' 2,000-run study found most 2024 models degrading past 16k to 64k tokens, with failure modes that differ by model — one started refusing on copyright grounds half the time at 64k.

**Retrieval quality is a matter of engineering detail.** Barnett et al.'s seven failure points from deployed systems are mostly about ranking and extraction, not embeddings. Anthropic's fix for the chunk-context problem — have a model prepend a 50 to 100 token description to each chunk before indexing — took the retrieval failure rate from 5.7% to 3.7%, then to 2.9% with a contextual keyword index and 1.9% with a reranker. LongMemEval's design study found similar levers for conversational memory: index at the granularity of a single exchange rather than a session, augment keys with extracted facts, and expand queries with time expressions.

**Graphs answer the questions retrieval cannot.** GraphRAG's paper opens with the failure it targets: retrieval "fails on global questions directed at an entire text corpus, such as 'What are the main themes in the dataset?'". Its community summaries beat vector retrieval on comprehensiveness in 72 to 83% of judged comparisons at a fraction of the tokens, at the price of an indexing pass that reads every chunk with a model. Zep's Graphiti adds the other missing dimension: a bi-temporal model that records when a fact was true and when the system learned it, so a contradicted fact is invalidated rather than deleted. On LongMemEval it reports 71.2% against 60.2% for full context, using 1,600 tokens instead of 115,000.

**Agent memory systems are the same ideas applied to conversation.** The vocabulary comes from the CoALA paper (2023): working memory is what is in the context window; long-term memory splits into episodic (what happened), semantic (facts about the world and the user) and procedural (how to act). MemGPT (2023), now Letta, treats the context window as RAM and gives the model tools to page facts in and out of always-visible "memory blocks". Mem0 (2025) extracts candidate facts from each exchange and has a model decide to add, update, delete or ignore each one against the nearest existing memories. A-MEM (NeurIPS 2025) is explicitly Zettelkasten-shaped: each memory is a note with generated keywords, tags and links, and a new note can trigger revisions to its neighbours. All of them descend from the Generative Agents memory stream (2023), which scored memories on recency, importance and relevance and ran a "reflection" pass when enough had accumulated.

**The benchmarks say less than the vendors claim.** Two facts stand out from LoCoMo and LongMemEval. First, at a scale that fits in the context window, full context is usually the most accurate option — Mem0's own paper reports 72.9 for full context against 68.4 for its best configuration, and sells latency and cost rather than accuracy. Second, the mechanism matters less than the management: Letta's August 2025 experiment gave an agent nothing but the conversation history in files plus grep and search, and scored 74.0 on LoCoMo with a small model, above Mem0's published 68.5. Their conclusion: "memory is more about how agents manage context than the exact retrieval mechanism used." The vendor numbers themselves have been through a public dispute — Zep's rebuttal of Mem0 was corrected from about 80% to 75.14% after a scoring error, and a 2026 analysis found around 6% of LoCoMo's ground truth corrupted. Treat any single-trial, self-reported figure as marketing.

**The index is the product.** The practical version of all of this appeared when Obsidian shipped its official command-line interface in February 2026. One widely repeated measurement: finding orphan notes in a 4,663-file vault cost an agent roughly seven million tokens by reading files, and about a hundred through the CLI's backlink index. An agent with only read and list tools re-reads raw markdown for every structural question; one with search, backlinks and orphan queries asks the index. That is the same lesson as Anthropic's just-in-time retrieval, LongMemEval's key expansion and Karpathy's `index.md`: whatever else the second brain contains, it needs a structure the model can consult without reading everything.

## 5. The landscape in 2026

The products sort into three families by where the notes live and who the AI works for.

| Family | Examples | Where the notes live | What the AI does | State in September 2026 |
|---|---|---|---|---|
| Hosted, source-grounded assistants | NotebookLM (renamed Gemini Notebook, July 2026), Notion AI, Mem 2.0, Reflect, Tana, Capacities, Heptabase, Recall | Vendor cloud, usually a proprietary store; export varies | Answers grounded in uploaded sources with citations, audio and video overviews, auto-tagging, related-note surfacing, agentic editing of notes | Mature and fast-moving; NotebookLM claims 30 million users; Notion 3.0 agents run 20-minute workflows with "memory pages" |
| File-based vault plus agent | Obsidian with Claude Code, Codex or Cursor; Logseq; gbrain; claude-obsidian; PAI/LifeOS | Markdown files the owner controls, typically in git | Whatever the agent is told to do: file, link, summarise, lint, answer; the vault is the agent's context | The 2026 growth area; the Obsidian CEO's agent-skills repository passed 47,000 stars in eight months |
| Capture-everything lifelogs | Microsoft Recall, Limitless pendant, Rewind | Local encrypted store (Recall) or vendor cloud | Screenshot or audio capture, OCR and transcription, search over your past | Contested or gone: Recall relaunched opt-in after a security backlash; Limitless was bought by Meta and shut down for EU and UK customers with a two-week export window |

The volatility in the third column is the clearest argument in this section. In the twelve months before this guide was written: Meta announced the Limitless acquisition on 5 December 2025, pendant sales stopped the same day, the Rewind app disabled all capture on 19 December, and accounts in the EU, UK, Brazil, South Korea, Israel and Turkey were terminated with a two-week export window. Google renamed NotebookLM. Logseq split into a file-based "OG" version in maintenance mode and a database version. Anytype was still prototyping its AI features. Each of these stranded, moved or renamed somebody's second brain, which is why Steph Ango's 2023 essay "File over app" reads as engineering advice rather than philosophy: "if you want to create digital artifacts that last, they must be files you can control, in formats that are easy to retrieve and read … Apps are ephemeral, but your files have a chance to last."

**The file-based stack is now supported from the top.** Obsidian, whose stated position is no built-in AI and no training on user notes, shipped the pieces an agent needs one by one: a Web Clipper that saves pages as Markdown (November 2024), Bases, which turn note properties into queryable tables (August 2025), a command-line interface that drives the running app so a move updates every wikilink (February 2026), and — maintained by its CEO — the `obsidian-skills` repository (January 2026), five agent skills that teach Claude Code, Codex or OpenCode the Markdown dialect, Bases, JSON Canvas, the CLI, and clean web extraction. The practitioner posts of 2026 describe the resulting workflow consistently: a `CLAUDE.md` under a hundred lines describing the vault's conventions, skills for the recurring jobs (daily note, weekly review, research, connection finding), rules that forbid deletion and renames, and the agent run inside the vault. Stefan Imhoff's account is representative in scale: over two sessions the agent reorganised more than 6,000 notes into a PARA and Zettelkasten tree, backlinked entities found in daily notes and enriched book and film notes with metadata.

**Self-hosted options exist at every layer.** Khoj (semantic search and chat over documents, with agents and scheduled automations), AnythingLLM and Open WebUI (workspace-scoped retrieval with hybrid search and citations) cover the hosted-assistant role on your own machine. Daniel Miessler's PAI, since renamed LifeOS, runs on Claude Code with personal goal files, tiered memory and hooks. Garry Tan's gbrain (April 2026) and the claude-obsidian project (April 2026) are direct implementations of the LLM-wiki pattern.

**The assistants are building a second brain of you, which you do not own.** ChatGPT's memory (February 2024, extended to all past conversations in April 2025), Claude's memory (September 2025 for teams, October for individuals, with an editable summary and project scoping), Gemini's "personal context" (on by default from August 2025) and Microsoft 365 Copilot Memory (July 2025) all maintain a model-written profile from your interactions. They are convenient and they are the opposite of file over app: the profile lives with the vendor, in the vendor's format, under the vendor's retention and training terms (section 6.4). Claude's memory import and export and ChatGPT's temporary chats are the concessions; none of them is a store you can point another tool at.

## 6. What the evidence says

The popular case against offloading rests on a handful of studies that are quoted far more often than they are read. Sorting them by what actually replicates changes the picture.

### 6.1 Robust findings and unreplicated ones

| Claim | Source | Status |
|---|---|---|
| Generating an answer produces better memory than reading it | Slamecka and Graf 1978; Bjork's "desirable difficulties" | Robust across decades of replication |
| Retrieval practice beats re-reading for retention, and learners misjudge this | Roediger and Karpicke 2006 | Robust; a week later, tested students retained substantially more than re-readers |
| Whether people offload is driven by metacognitive judgements that are often wrong | Risko and Gilbert 2016 | Review; offloading is a trade-off, "neither good nor bad in itself" |
| "Google effect": expecting information to be saved reduces memory for it | Sparrow, Liu and Wegner 2011 | Mixed. The Stroop-priming experiment failed replication twice (2018, 2020); a 2024 meta-analysis of 35 comparisons finds a moderate overall effect on memory reliance |
| Longhand notes beat laptop notes for learning | Mueller and Oppenheimer 2014 | Did not replicate (Morehead 2019; Urry 2021). Laptop users do write more verbatim; they do not learn less |

The robust column is the theoretical core of "the writing is the thinking": producing and retrieving are the encoding, and fluent conditions produce a false sense of mastery. The unreplicated column is where most of the "your brain on Google" headlines came from.

### 6.2 What AI-specific studies show

The pattern across the 2025 and 2026 work is consistent, and more specific than "AI makes you dumber".

- **Answers harm unaided performance; hints do not.** Bastani et al. (PNAS, June 2025) ran a field trial with nearly 1,000 Turkish high-school mathematics students. During practice, a plain ChatGPT interface raised performance 48% over control and a version prompted to give hints rather than answers raised it 127%. On the unaided exam that followed, the plain-ChatGPT group scored 17% *worse* than control; the hint-giving version was level with control. Students with the unrestricted tool asked for answers instead of working the problems.
- **Summaries produce shallower knowledge.** Melumad and Yun (PNAS Nexus, October 2025), across experiments with 4,591 participants, had people learn practical topics from LLM summaries or from web search with matched facts. The LLM learners developed shallower knowledge, felt less invested and wrote sparser advice that others were less likely to adopt. The synthesis format removes the integration the reader would otherwise do.
- **Persistence drops.** Liu et al. (2026) found in randomised trials with 1,222 participants that after about ten minutes of AI help, people performed worse and gave up sooner once the help was removed.
- **You forget which ideas were yours.** Zindulka et al. (pre-registered, 184 participants) found that a week after a mixed human-and-AI writing session, people could not reliably say which ideas were theirs. For a vault that an agent edits, this is the finding that matters most; it is also what Simon Späti reports from the inside: "Over time, I don't know anymore whether the content was written by me or by an AI, and my own, much more valuable thoughts get diminished by 'AI Slop'."
- **Cognitive surrender.** Shaw and Nave (Wharton, 2026 working paper, 1,372 participants) found that when an available AI was wrong, most participants accepted the wrong answer, and their confidence rose regardless. They separate this from offloading: in offloading you still own the answer.
- **The counterweight.** Huang et al.'s meta-analysis of 133 studies (September 2025) finds the overall effect of LLMs on learning "positive but uneven", strongest when the model acts as a scaffolded tutor over a sustained period. Design and duration matter more than the tool.

The most quoted study is the weakest. MIT Media Lab's "Your Brain on ChatGPT" (June 2025) had 54 participants writing essays under EEG, of whom 18 returned for the crossover session that produced the "struggled when the tool was removed" headline — roughly nine per arm. It remains an unreviewed preprint with a formal methods commentary against it, and its authors' own FAQ asks journalists not to use the words "brain rot", "damage" or "brain scans". The two large surveys usually cited alongside it, Lee et al. (CHI 2025, 319 knowledge workers) and Gerlich (2025, 666 UK participants), are self-report and cross-sectional; they show that confidence in the tool correlates with less reported critical thinking, and cannot show that anyone's thinking declined.

### 6.3 Reliability

Grounding an assistant in your own sources reduces fabrication; it does not remove it, and the residual errors are of a kind that is hard to notice.

- Hagar, Agustianto and Diakopoulos (2025) gave ChatGPT, Gemini and NotebookLM a 300-document corpus for a reporting task. Thirty percent of outputs contained at least one hallucination — around 40% for the chat tools, around 13% for NotebookLM. The dominant error was "interpretive overconfidence": unsupported characterisations, and attributed opinions turned into general claims, rather than invented numbers.
- Peters and Chin-Yee (Royal Society Open Science, 2025) compared 4,900 model-written summaries of scientific papers across ten models. Most models overgeneralised beyond the source, in 26 to 73% of cases for the worst of them, even when prompted for accuracy, and were about five times more likely to do so than human summaries.
- The Australian regulator ASIC's 2024 trial is real but weaker than its citations suggest: five assessors scored human summaries of inquiry submissions at 81% and Llama 2's at 47%, after one week of prompt tuning on an already dated model.
- No verified incident of an agent corrupting a notes vault was found. The general-purpose incidents are well documented — Gemini CLI deleting a user's project after hallucinating a successful move (July 2025), Replit's agent deleting a production database during a declared freeze (July 2025), Google Antigravity wiping a drive when asked to clear a cache (December 2025) — and Karpathy's gist warns that in a compiled wiki, errors are "permanently embedded" unless lint passes catch them.

The consequence for a second brain: an AI-written summary in the vault is a claim about a source, not the source, and a wiki page that no human has read is a claim about the wiki. Both need provenance and a review step, the same as generated code.

### 6.4 Privacy and ownership

Microsoft Recall is the reference case. Announced in May 2024 as on-by-default screenshots every few seconds, it was shown within days to store OCR text in a plaintext SQLite database readable by any process running as the user; a tool to extract it took seconds. Microsoft pulled it before launch and shipped it in April 2025 as opt-in with a second confirmation, Windows Hello to view, encryption in a virtualisation-based enclave, local-only processing and a sensitive-data filter that independent tests still found leaking that August. The trust deficit outlived the fix: Signal, Brave and AdGuard all block Recall by default, AdGuard saying the only reliable protection is to disable it.

The training defaults of the assistants that hold the model-written profile are as verified in September 2026:

| Service | Consumer default | Notes |
|---|---|---|
| ChatGPT (Free, Plus, Pro) | Training on | "Improve the model for everyone" toggle; Business, Enterprise and API are off by default |
| Claude (Free, Pro, Max) | Explicit choice required since August 2025 | Retention five years if training is allowed, 30 days if not; safety-flagged conversations may be used regardless; work, API and education tiers excluded |
| Gemini | "Keep Activity" on | A subset of chats goes to human reviewers; 18-month default retention; reviewed chats kept up to three years |
| Notion AI | Off | Contractual prohibition on subprocessors training; zero retention at the model provider for Enterprise |

A capture-everything store is one acquisition away from a different data controller, as Limitless's customers found; a hosted profile is one policy update away from different terms. The file-based family in section 5 avoids both problems by construction, at the cost of doing the integration work yourself.

## 7. Building one

The extended-mind test from section 2 is the specification: a second brain counts only while it is constantly consulted, readily available and trusted. Language models make the first two conditions easy — an agent consults the vault on every task, and retrieval no longer needs the owner's filing — and make the third condition the whole problem. Everything below is in service of keeping the vault trustworthy while an agent writes to it.

### 7.1 Four layers with different owners

| Layer | Who writes it | Write policy | Example in this repository |
|---|---|---|---|
| Raw sources | Nobody, after capture | Immutable. Clippings, PDFs, transcripts, exports. | The dated references in each guide; captured pages would live beside them |
| Your notes | You | Human-written, human-edited. This is the thinking. An agent may propose; it does not overwrite. | `docs/` — the living guides |
| Derived layer | The agent | LLM-owned and regenerable: summaries, entity and concept pages, indexes, links. Marked as generated. | The auto-memory directory: a `MEMORY.md` index plus typed topic files |
| Schema | You, rarely | How the vault is structured, what the conventions are, which workflows to run. | `CLAUDE.md` |

The separation is Karpathy's raw-versus-wiki split with one layer added: a place for the owner's own writing that the agent treats as a source, not as output. That is the direct answer to the "AI memory gap" finding and to Späti's complaint. If the owner's notes and the model's notes are in one undifferentiated pile, within a week nobody can tell which is which, and the owner's part — the part that was the thinking — is what gets diluted.

### 7.2 Rules that follow from the evidence

1. **Version control and review the agent's writes.** Git, or at minimum the app's file recovery, plus a diff before accepting a reorganisation. Rules that forbid deletion and renames are standard in the 2026 practitioner setups, and the CLI-driven move that updates every wikilink is the safe form of the operation. Append-only or confirm-before-write for anything the agent touches in the human layer.
2. **Mark provenance in the file.** A property on generated pages, a generated folder, or a footer like the one on this guide. The reader a year from now will not remember.
3. **Run lint passes.** Contradictions, stale claims, orphans, concepts without pages, missing cross-references. This is the only defence against the "permanently embedded" error, and the derived layer has no value without it.
4. **Choose retrieval by size, and give the agent an index.** Under about 200,000 tokens, full context with caching. Above that, a search and backlink index the agent can query rather than files it must read, contextual chunking if you build retrieval yourself, and temporal validity if the facts change.
5. **Keep the thinking steps human where learning matters.** Let the agent do Capture and Organize; keep Distill and Express — reading the source, writing the summary in your own words, deciding what it means for a project — when the point is to know the material rather than to have it. Section 6.2's trial is the guide: hints rather than answers, and attempt first.
6. **Prefer the sparring partner to the librarian for hard questions.** Form an expectation before reading the model's answer, ask it to argue against itself, and work without it deliberately sometimes. The "thinking partner" framing invites cognitive surrender; the sparring-partner framing forces a defence.
7. **Decide where the content may go.** Whole-vault access through a hosted tool sends the vault to a remote API per query. For sensitive notes, use a local model, a read-only exposure, or keep them out of the agent's path. Check the training default of any assistant that holds a profile of you.
8. **Files over apps.** Markdown in a directory you control, in git. Every product in section 5 that stranded its users was a store the user did not own.

### 7.3 What this repository already is

This repository is a second brain of the shape described, built for two readers. The guides under `docs/` are the human-written layer: one canonical document per question, revised in place, with the git history as the changelog. `CLAUDE.md` is the schema — what the repository is, how it is built, what the conventions are — and it is loaded into every agent session. The auto-memory directory beside the project is the agent-written layer: a `MEMORY.md` index of one line per note plus typed topic files, which is Karpathy's `index.md` and pages in miniature, maintained by the agent and read on demand. The strict site build is the lint pass for the human layer; nothing yet lints the derived one.

The gap is the raw-sources layer. The references in each guide are links, not captures, so a source that moves or disappears takes its evidence with it. The natural prototype from this research is small: capture the references of one guide as Markdown beside it, have an agent build and lint a wiki over them following the schema in section 7.1, and measure two things — whether the wiki answers the guide's questions with correct citations, and how often a lint pass finds a claim the guide itself got wrong.

## 8. References

### Origins and theory

- Vannevar Bush, "As We May Think", *The Atlantic*, July 1945: https://www.theatlantic.com/magazine/archive/1945/07/as-we-may-think/303881/ (plain-text mirror: https://www.w3.org/History/1945/vbush/vbush.txt)
- Douglas Engelbart, "Augmenting Human Intellect: A Conceptual Framework", 1962: https://www.dougengelbart.org/content/view/138
- Andy Clark and David Chalmers, "The Extended Mind", *Analysis*, 1998: https://consc.net/papers/extended.html
- Niklas Luhmann, "Communicating with Slip Boxes", 1981 (2023 translation): https://zettelkasten.de/communications-with-zettelkastens/
- Sönke Ahrens, *How to Take Smart Notes*: https://www.soenkeahrens.de/en/takesmartnotes
- Tiago Forte, "Building a Second Brain: An Overview": https://fortelabs.com/blog/basboverview/ ; "The PARA Method": https://fortelabs.com/blog/para/ ; "Progressive Summarization": https://fortelabs.com/blog/progressive-summarization-a-practical-technique-for-designing-discoverable-notes/ ; "12 Favorite Problems": https://fortelabs.com/blog/12-favorite-problems-how-to-spark-genius-with-the-power-of-open-questions/
- Tiago Forte, "Introducing The AI Second Brain", 13 March 2026: https://fortelabs.com/blog/introducing-the-ai-second-brain/ ; "Is Recall the Second Brain for the AI Era?", 9 July 2026 (sponsored): https://fortelabs.com/blog/is-recall-the-second-brain-for-the-ai-era/
- Andy Matuschak, "Evergreen notes": https://notes.andymatuschak.org/Evergreen_notes ; "Most people use notes as a bucket for storage or scratch thoughts": https://notes.andymatuschak.org/Most_people_use_notes_as_a_bucket_for_storage_or_scratch_thoughts ; "People who write extensively about note-writing rarely have a serious context of use": https://notes.andymatuschak.org/People_who_write_extensively_about_note-writing_rarely_have_a_serious_context_of_use ; "Why books don't work", 2019: https://andymatuschak.org/books/
- Maggie Appleton, "A Brief History & Ethos of the Digital Garden", 2020: https://maggieappleton.com/garden-history
- Mike Caulfield, "The Garden and the Stream: A Technopastoral", 2015: https://hapgood.us/2015/10/17/the-garden-and-the-stream-a-technopastoral/
- Christian Tietze, "The Collector's Fallacy", 2014: https://zettelkasten.de/posts/collectors-fallacy/
- Sasha Chapin, "Notes Against Note-Taking Systems", 2022: https://sashachapin.substack.com/p/notes-against-note-taking-systems
- Reagan Rose, "The Failed Promise of Connected Note-Taking Apps", 2023: https://redeemingproductivity.com/the-failed-promise-of-connected-note-taking-apps/
- Joan Westenberg, "I Deleted My Second Brain", July 2025: https://medium.com/westenberg/i-deleted-my-second-brain-b7a65bce3717
- Daniel Wentsch, "When Your Second Brain Eats Your First One", October 2025: https://zettel.org/when-your-second-brain-eats-your-first-one/

### Context engineering and the LLM wiki

- Andrej Karpathy, "LLM Wiki" idea file, 4 April 2026: https://gist.github.com/karpathy/442a6bf555914893e9891c11519de94f
- Tobi Lütke on context engineering, 18 June 2025: https://x.com/tobi/status/1935533422589399127 ; Andrej Karpathy, 25 June 2025: https://x.com/karpathy/status/1937902205765607626 ; Simon Willison, "Context engineering", 27 June 2025: https://simonwillison.net/2025/jun/27/context-engineering/
- Anthropic, "Effective context engineering for AI agents", 29 September 2025: https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents
- Anthropic, "Introducing Contextual Retrieval", 19 September 2024: https://www.anthropic.com/news/contextual-retrieval
- Anthropic, "Managing context on the Claude Developer Platform" (memory tool and context editing), 29 September 2025: https://claude.com/blog/context-management
- Claude Code memory documentation: https://code.claude.com/docs/en/memory
- AGENTS.md: https://agents.md/ ; Cursor rules: https://cursor.com/docs/context/rules ; GitHub Copilot repository instructions: https://docs.github.com/en/copilot/how-tos/configure-custom-instructions/add-repository-instructions
- Cognition, "DeepWiki", 25 April 2025: https://cognition.com/blog/deepwiki

### Memory architectures and benchmarks

- Lewis et al., "Retrieval-Augmented Generation for Knowledge-Intensive NLP Tasks", 2020: https://arxiv.org/abs/2005.11401
- Barnett et al., "Seven Failure Points When Engineering a RAG System", 2024: https://arxiv.org/abs/2401.05856
- Liu et al., "Lost in the Middle", 2023: https://arxiv.org/abs/2307.03172
- Databricks, "Long Context RAG Performance of LLMs", August 2024: https://www.databricks.com/blog/long-context-rag-performance-llms
- Chroma, "Context Rot", July 2025: https://www.trychroma.com/research/context-rot
- Edge et al. (Microsoft), "From Local to Global: A Graph RAG Approach to Query-Focused Summarization", 2024: https://arxiv.org/abs/2404.16130 ; LazyGraphRAG, November 2024: https://www.microsoft.com/en-us/research/blog/lazygraphrag-setting-a-new-standard-for-quality-and-cost/
- Sumers et al., "Cognitive Architectures for Language Agents", 2023: https://arxiv.org/abs/2309.02427
- Park et al., "Generative Agents", 2023: https://arxiv.org/abs/2304.03442
- Packer et al., "MemGPT: Towards LLMs as Operating Systems", 2023: https://arxiv.org/abs/2310.08560 ; Letta memory blocks: https://docs.letta.com/guides/agents/memory-blocks/
- Chhikara et al., "Mem0: Building Production-Ready AI Agents with Scalable Long-Term Memory", 2025: https://arxiv.org/abs/2504.19413
- Rasmussen et al., "Zep: A Temporal Knowledge Graph Architecture for Agent Memory", 2025: https://arxiv.org/abs/2501.13956 ; Graphiti: https://github.com/getzep/graphiti
- Xu et al., "A-MEM: Agentic Memory for LLM Agents", 2025: https://arxiv.org/abs/2502.12110
- LangMem: https://langchain-ai.github.io/langmem/
- Lin et al. (Letta), "Sleep-time Compute", 2025: https://arxiv.org/abs/2504.13171
- Maharana et al., "Evaluating Very Long-Term Conversational Memory of LLM Agents" (LoCoMo), 2024: https://arxiv.org/abs/2402.17753
- Wu et al., "LongMemEval", 2024: https://arxiv.org/abs/2410.10813 ; LongMemEval-V2, May 2026: https://arxiv.org/abs/2605.12493
- Letta, "Benchmarking AI Agent Memory: Is a Filesystem All You Need?", 12 August 2025: https://www.letta.com/blog/benchmarking-ai-agent-memory/
- Zep, "Lies, Damn Lies, Statistics: Is Mem0 Really SOTA in Agent Memory?", May 2025: https://blog.getzep.com/lies-damn-lies-statistics-is-mem0-really-sota-in-agent-memory/ and the correction: https://github.com/getzep/zep-papers/issues/5

### Products and practitioner patterns

- Steph Ango, "File over app", 1 July 2023: https://stephango.com/file-over-app
- Obsidian skills (kepano): https://github.com/kepano/obsidian-skills ; Obsidian CLI: https://obsidian.md/help/cli ; Obsidian changelog: https://obsidian.md/changelog/ ; Web Clipper announcement: https://obsidian.md/blog/save-the-web/
- Ilya Prokopov, "Obsidian CLI changes everything for AI agents", February 2026: https://prokopov.me/posts/obsidian-cli-changes-everything-for-ai-agents/
- Stefan Imhoff, "Agentic note-taking with Obsidian and Claude Code", March 2026: https://www.stefanimhoff.de/writing/agentic-note-taking-obsidian-claude-code/
- "Claude Code + Obsidian: build a second brain that actually thinks", April 2026: https://dev.to/mibii/claude-code-obsidian-build-a-second-brain-that-actually-thinks-d61
- Simon Späti, "Using Obsidian with AI", 2026: https://www.ssp.sh/brain/using-obsidian-with-ai/
- Mem, "Your notes are a mess. That's fine.": https://get.mem.ai/guides/your-notes-are-a-mess-thats-fine ; Mem 2.0 launch, October 2025: https://get.mem.ai/blog/introducing-mem-2-0
- Notion releases: Q&A (November 2023): https://www.notion.com/releases/2023-11-14 ; Notion 3.0 agents (September 2025): https://www.notion.com/releases/2025-09-18
- NotebookLM: Audio Overviews, September 2024: https://blog.google/technology/ai/notebooklm-audio-overviews/ ; renamed Gemini Notebook, July 2026: https://9to5google.com/2026/07/16/notebooklm-gemini-notebook/
- Khoj: https://github.com/khoj-ai/khoj ; AnythingLLM: https://github.com/Mintplex-Labs/anything-llm ; Open WebUI knowledge: https://docs.openwebui.com/features/workspace/knowledge/ ; Daniel Miessler, "Personal AI Infrastructure": https://danielmiessler.com/blog/personal-ai-infrastructure ; gbrain: https://github.com/garrytan/gbrain ; claude-obsidian: https://github.com/AgriciDaniel/claude-obsidian
- OpenAI, "Memory and new controls for ChatGPT", February 2024: https://openai.com/index/memory-and-new-controls-for-chatgpt/ ; Anthropic, "Bringing memory to Claude", September 2025: https://claude.com/blog/memory ; Google, "Gemini with personalization", March 2025: https://blog.google/products-and-platforms/products/gemini/gemini-personalization/
- Meta acquires Limitless, 5 December 2025: https://www.cnbc.com/2025/12/05/meta-limitless-ai-wearable.html ; Rewind shutdown: https://9to5mac.com/2025/12/05/rewind-limitless-meta-acquisition/
- Microsoft Recall: security analysis, June 2024: https://doublepulsar.com/how-the-new-microsoft-recall-feature-fundamentally-undermines-windows-security-aa072829f218 ; pulled from launch, 7 June 2024: https://blogs.windows.com/windowsexperience/2024/06/07/update-on-the-recall-preview-feature-for-copilot-pcs/ ; opt-in release, 25 April 2025: https://blogs.windows.com/windowsexperience/2025/04/25/copilot-pcs-are-the-most-performant-windows-pcs-ever-built-now-with-more-ai-features-that-empower-you-every-day/ ; Brave blocks Recall: https://brave.com/privacy-updates/35-block-recall/
- Kleppmann et al., "Local-first software", 2019: https://www.inkandswitch.com/essay/local-first/

### Evidence

- Slamecka and Graf, the generation effect, 1978; Bjork Learning and Forgetting Lab: https://bjorklab.psych.ucla.edu/research/
- Roediger and Karpicke, "Test-Enhanced Learning", 2006: https://journals.sagepub.com/doi/10.1111/j.1467-9280.2006.01693.x
- Risko and Gilbert, "Cognitive Offloading", 2016: https://www.cell.com/trends/cognitive-sciences/abstract/S1364-6613(16)30098-5
- Sparrow, Liu and Wegner, "Google Effects on Memory", 2011: https://www.science.org/doi/10.1126/science.1207745 ; Hesselmann et al. replication, 2020: https://peerj.com/articles/10325/ ; Gong and Yang meta-analysis, 2024: https://www.frontiersin.org/journals/public-health/articles/10.3389/fpubh.2024.1332030/full
- Morehead, Dunlosky and Rawson, 2019: https://link.springer.com/article/10.1007/s10648-019-09468-2 ; Urry et al., 2021: https://journals.sagepub.com/doi/abs/10.1177/0956797620965541
- Kosmyna et al., "Your Brain on ChatGPT", preprint, June 2025: https://arxiv.org/abs/2506.08872 ; the authors' FAQ: https://www.media.mit.edu/projects/your-brain-on-chatgpt/overview/ ; methods commentary, December 2025: https://arxiv.org/abs/2601.00856
- Lee et al., "The Impact of Generative AI on Critical Thinking", CHI 2025: https://dl.acm.org/doi/10.1145/3706598.3713778
- Gerlich, "AI Tools in Society", *Societies*, 2025: https://www.mdpi.com/2075-4698/15/1/6
- Bastani et al., "Generative AI without guardrails can harm learning", *PNAS*, 2025: https://www.pnas.org/doi/10.1073/pnas.2422633122
- Melumad and Yun, *PNAS Nexus*, 2025: https://academic.oup.com/pnasnexus/article/4/10/pgaf316/8303888
- Liu et al., "AI assistance reduces persistence and hurts independent performance", 2026: https://arxiv.org/abs/2604.04721
- Zindulka et al., "The AI Memory Gap", 2025: https://arxiv.org/abs/2509.11851
- Shaw and Nave, cognitive surrender, working paper, 2026: https://papers.ssrn.com/sol3/papers.cfm?abstract_id=6097646 ; Addy Osmani, "Cognitive surrender", May 2026: https://addyosmani.com/blog/cognitive-surrender/ ; Mike Kentz, "From thinking partner to sparring partner", July 2025: https://mikekentz.substack.com/p/from-thinking-partner-to-sparring
- Huang et al., meta-analysis of LLM effects on learning, 2025: https://arxiv.org/abs/2509.22725
- Hagar, Agustianto and Diakopoulos, hallucination in grounded assistants, 2025: https://arxiv.org/abs/2509.25498
- Peters and Chin-Yee, "Generalization bias in large language model summarization", *Royal Society Open Science*, 2025: https://royalsocietypublishing.org/rsos/article/12/4/241776/235656/Generalization-bias-in-large-language-model
- ASIC and AWS summarisation trial, 2024: https://ia.acs.org.au/article/2024/humans-outperform-ai-in-australian-govt-trial.html
- Agent incidents: Gemini CLI: https://incidentdatabase.ai/cite/1178/ ; Replit: https://fortune.com/2025/07/23/ai-coding-tool-replit-wiped-database-called-it-a-catastrophic-failure/ ; Antigravity: https://www.theregister.com/2025/12/01/google_antigravity_wipes_d_drive/
- Training defaults: OpenAI: https://help.openai.com/en/articles/5722486-how-your-data-is-used-to-improve-model-performance ; Anthropic: https://www.anthropic.com/news/updates-to-our-consumer-terms ; Google: https://support.google.com/gemini/answer/13594961?hl=en ; Notion: https://www.notion.com/help/notion-ai-security-practices

### Related in this repository

- [AI Development with Loops and Graphs](loops-and-graphs.md) — the agent loop that a second brain feeds; its [section 10](loops-and-graphs.md#10-memory-state-that-outlives-the-loop) covers memory from the agent's side.
- [Vertical Slice Architecture for AI Development](vertical-slice-architecture.md) — bounded context for coding agents, the same concern applied to code rather than notes.

---

*Compiled from a four-agent research sweep on 2 September 2026 (origins and theory; products and practitioner patterns; memory architectures and benchmarks; evidence and critiques), with the central primary sources — Karpathy's gist, the Obsidian skills repository, Forte's 2026 post and Ango's essay — re-read directly. Vendor benchmark figures are reported as published and flagged where disputed; star counts and product states are as of that date and will age.*
