---
version: "0.1.2"
level: auto
processes:
  design: copilot
  implementation: copilot
  testing: copilot
  documentation: copilot
  review: auto
  deployment: copilot
---

This declaration follows the [AI-DECLARATION.md](https://ai-declaration.md/en/0.1.2/) format.

## Notes

- Braincell1980, the maintainer, does not write code. He decides what Tessera does, how it looks and when a version ships.
- Claude (an AI by Anthropic) writes all the Lua code, the automated tests, the release tools and most of the documentation, from his instructions, and asks him before choices that matter.
- Testing: Claude writes and runs the automated checks before each push; Braincell1980 tests each version in WoW Forever before release.
- Review is the only `auto` stage: no human reads the code line by line. For risky changes, a second AI session reviews the plan and the code.
- Deployment: Claude wrote the release workflows, and nothing is published without Braincell1980's go.
- See also `ACR.md` (AI Code Rating E4d).
