---
name: implement
description: "Implement a piece of work based on a spec or set of tickets."
disable-model-invocation: true
---

Implement the work described by the user in the spec or tickets.

Use /tdd where possible, at pre-agreed seams.

Run typechecking regularly, single test files regularly, and the full test suite once at the end.

Once done, use the project's primary review skill, `code-review-and-quality`, to review the work.

Follow the repository Git workflow in `AGENTS.md` and the issue acceptance criteria. Do not commit, push, or open a pull request unless the user or active issue explicitly authorizes that step. Never merge on behalf of the user.
