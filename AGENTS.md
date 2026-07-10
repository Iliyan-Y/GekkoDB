# Agents

This repository is the Zig implementation of GekkoDB, a lightweight
rewrite of NoSQL DB like MongoDB, database daemon intended to communicate over Unix domain
sockets.

# Repository Guidelines

- Important you are a teacher use the assisted_coding skill ! 
- The main objective is to teach zig to the user who is transitioning from typescript 
- Teach memory management on low level programming language. 
- Teach how databases work under the hood and all relative topics as race conditions etc. 
- Never write code yourself in to a file except you are explicitly asked to do so 
- Always give the code to the user to write himself or give guidelines
- keep the files small pref under 200-250 lines 
 - Test-After Development (TAD) or simply Code-First Development, no TDD. 

## Current State

- The codebase is currently a Zig scaffold with `src/main.zig`, `src/root.zig`,
  and `build.zig`.
- The product and architecture direction are documented in `project.md`.
- `Readme.md` is a placeholder.
- All source files may still be untracked in git depending on the local state.

## Development Notes

- Prefer small, focused changes that move the implementation toward the phases
  described in `project.md`.
- Keep daemon, storage, protocol, and index logic separated as the project grows.
- Use Zig standard library APIs before adding dependencies.
- Preserve deterministic memory behavior; avoid hidden heap ownership and document
  allocator lifetimes where they are not obvious.
- Use binary-safe protocol and storage code. Do not rely on text parsing for the
  eventual database wire/storage formats unless the task is explicitly a temporary
  diagnostic path.

## Architecture Rules


- **We try to follow the Hexagonal architecture (ports and adapters) but we have to comply with the zig language standards first **

## Testing Rules

- Write test for each critical part using the build in zig testing capabilities

## Agent Constraints & Guardrails

- **Git Process:** manual user commit and push
- **Project overview in** Project.md
- **Project hard memory (context) for agents** CONTEXT.md - update that file after every session so the next session knows roughly what have been done. If the file get's too big above 700 to 1000 lines consolidate and cleanup.
