---
name: brainstorming
description: "Use when starting any creative work - creating features, building components, adding functionality, or modifying behavior. Explores user intent, requirements and design before implementation."
effort: medium
---

# Brainstorming

You build what you believe your human partner wants, and that belief is usually thinner than it feels. This skill is for finding out what they actually want, and why, before anything gets built. When you understand the why, you make the hundred decisions they never mention the way they would have made them.

## First: What Do You Actually Know?

Before you reply, ask yourself: what do I know about what they want, and why?

- **Everything that matters is in the request** ("make the icon cornflower blue"). This is a quick, clear task. Do it, and say what you did.
- **Something non-trivial is missing.** Start the conversation.

Before you start implementing, you must, in order:

1. Lay out the approaches in a message of their own, and have your human partner pick one (see Lay out the approaches).
2. Give them the design: in chat for a small change, a written document for a project (see Size the Work).
3. Get their approval of that design.

If nothing is open when you write your first message and there's one sensible way, all three happen in that message (see Your First Message).

A spike they said yes to isn't implementing, nor is doing what they asked once they've opted out of the questions.

## Look Before You Ask

In an existing project, or when they've given you context (a spec, a plan, a handoff, files they pointed at, earlier conversation), read it and the code it connects to before your first message, until you can explain how the relevant parts work today and what this change would touch. Reading is not building. Never ask what the project or their context already answers, or reopen what they've already decided.

## Your First Message

Move the work forward, with one of these:

- **They've already said what they want** (a spec, a plan, a detailed request): aim for about 200 words. Echo their request back in your own words, so they can see whether you've got its shape: what they want, who it's for, and why, as far as they've said. Add what you found that bears on it. If you found something they may not have considered that would change what they're asking for or how it has to be built (a constraint, a conflict, a cheaper path), say so plainly. Invite corrections in one line. Then:
  - If they haven't told you why they want it, even if you can guess, ask that: one open question in their own terms, with nothing to pick from.
  - If they have, and something is still open whose answer would change what gets built, ask about the one that would change it most. When its choices can be named, sketch each concretely, with what it trades off and which you'd pick.
  - If nothing like that is open, there's one sensible way: end with the short design itself (the approach, a line on why the others don't fit, and the design in a few lines) and ask them to approve it. Their approval covers the approach and the design.
- **They haven't:** one open question, in their own terms, about the biggest thing their request leaves unsettled. Say what the answer would change about what you build. For "a website for my bakery": "If it's mostly for people deciding whether to stop by, I'd lead with hours and what's in the case today; taking orders is a different site. What do you want someone to do when they land on it?"

How the message ends depends on whether they asked for brainstorming:

- **They asked for it** (by name, by invoking it, or by asking for a design discussion): end there. They want this conversation, so don't offer to skip it.
- **They didn't:** they may not want a conversation at all. End with a light, one-line offer to just get going instead, like "Or if you'd rather I just dive in, say so." If they take you up on it, this skill is done: state any significant how-it-gets-made choice (platform, language, medium) in one plain line, then do what they asked through the normal workflow.

That's the whole message.

**When it's unattended.** Unattended means an explicit signal only: a headless or non-interactive run (`claude -p`, `codex exec`), a background or subagent session, or the user or prompt saying not to wait or to proceed without them. Never infer it from a missing question tool. When unattended, treat it as the opt-out: make the calls yourself, and for project-sized work still write the design document with every call marked as yours, so they can review it when they're back.

## The Conversation

Ask a question only when the answer would change what gets built and neither the request nor the project answers it. Otherwise, state your call and your reason as a proposal they can correct, and move the work forward. Process steps are always your calls: writing things up, where files go, looking further, how to show something. Do them and say so. Ask one question at a time. Use plain language and their vocabulary; never use process jargon. Lead with what matters: when you report what you found, give the most important findings and offer the rest.

**Get them describing.** Until you know why they want it, ask open questions, with no example answers attached. Their own words carry intent that your options can't. Once you know why, when a decision has choices you can name, sketch each concretely, with what it trades off and which you'd pick (in Codex, `request_user_input` with `autoResolutionMs` when available). When they say "just guess" or "what do you think?", propose something concrete.

**How it gets made.** Every project rests on choices like platform, language, and libraries. Read from how they talk which of those choices they want to make. Someone who raises the how or asks about trade-offs wants the options with your pick. Someone who talks about outcomes is handing you the how: make those calls and state each in a line. When there's existing work, build on what it already uses. Any choice you make goes in the design as your call, never as something they agreed to.

**Ground to cover.** Territory, not a script; never read these out as questions: what kind of thing this is, why now and what success looks like, goals, non-goals and anti-goals (what would make it a failure even if it works), prior art they've loved or hated, what exists now and what they've tried, the details they care about.

**Make every question specific** to their project and what they've told you. Build each question on their last answer or on something you found, so it helps them think through a consequence or a case they may have missed ("Voting closes before the meeting, and two members joined this month. Does someone who joins mid-round get a vote?"). When the reason isn't already plain, say what the answer would change.

**Do recon.** When looking further would help, go look: deeper into their codebase, their own files and data, or the web. Say what you looked for and what you found.

**Lay out the approaches.** Once you understand what they want, and before you write anything up, put the ways of building it in a message of its own. Come up with several real alternatives and drop the weak ones, including any that work against why they want it and any the existing work rules out. Sketch the two or three that remain concretely, grounded in what the project actually does, with what each trades off. Recommend one and say why, then ask which way they want to go; if they've handed you the how, say you'll go with your pick instead. When there's genuinely one sensible way, say so and explain why the others don't fit. This is for how it gets built; for what they want, get them describing first.

**Spike to feel things out.** A quick throwaway build is often the cheapest way to learn what they want or whether something works. Offer one when it would help. Spikes skip tests, the plan, and review. Bring what the spike taught you back into the conversation.

## Play It Back

Play back as you go. As soon as you understand one part well enough to describe it, describe it back in about 200-300 words, then move on to the next part.

Only what they said goes in as theirs. Anything you filled in goes in as your proposal, with your reason. End each chunk by asking what's wrong or missing.

## Size the Work

Once you understand what they want and they've picked an approach, say how big the work is in plain words. They can override it.

| Size | The design | Then |
|------|------------|------|
| A quick, clear task | the request itself | do it |
| A small change | in chat: what you covered together, the approach they picked, and your own calls | once approved, build it through the normal workflow |
| A project | a written design document | once approved, superpowers-bd:using-git-worktrees, then superpowers-bd:writing-plans |

Calling something small never skips the approval: a small change still gets its design in chat and a yes before you build.

If it grows mid-task, stop, say so, and step up a size.

If this is really several independent projects, say so, agree on an order, and brainstorm them one at a time.

## The Written Design

For a project, write a plain document a talented builder could plan from without going back to your human partner. Cover:

- intent and the why
- goals, non-goals, anti-goals
- constraints
- approaches: the two or three you considered, what each trades off, which one they picked, and why
- the parts of the how they decided, as they decided them
- what's left to the builder

**Where it goes:** `docs/plans/YYYY-MM-DD-<topic>-design.md`, committed. Your human partner's preferences override this.

**Builder check:** read `builder-check-prompt.md` in this directory, dispatch a fresh subagent with it (the Agent tool in Claude Code, `spawn_agent` in Codex), and handle what comes back as that file says. When you tell your human partner you're writing it up, say a reviewer will read it first and you may come back once with a few questions. Don't hand over the document until the check is back. Without a subagent tool, read the document as that builder yourself.

Use elements-of-style:writing-clearly-and-concisely for the document if available.

<HARD-GATE>
Nothing gets built until your human partner approves the design: in chat for a small change, the document for a project.
Building includes writing product code, scaffolding, installing dependencies, creating projects, and invoking an implementation skill. Reading and exploring are fine.

Two exceptions. If they opted out of the questions, the skill is done and the gate goes with it. A spike they said yes to may be built; it stays labeled throwaway, and keeping what it produced is a new request that comes back through this gate.

</HARD-GATE>

## Red Flags

| Thought | Reality |
|---------|---------|
| "I'll offer a menu of what they might want" | Options steer. Ask them to describe it first; options are for how, once you know why. |
| "I'll end with a question to keep things moving" | A question they've already answered, or whose answer changes nothing, is filler. State your call. |
| "I've answered their questions, so I'll write it up" | Lay out the approaches first, in a message of their own. |
| "It's a small change, so I'll just build it" | Small changes the size of the design, not whether they approve it. |
| "They said 'sounds good' to the idea" | Approval covers what you showed them. A design you haven't written isn't approved. |
| "The spike works, I'll keep building on it" | Keeping it is a new request. Back through the gate. |
