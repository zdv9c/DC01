---
trigger: glob
description: Use when writing markdown anywhere in docs/T
globs: **/DC01/docs/**/*.md
---

# Documentation Standards

## 0. CRITICAL TEST
If you can read this, write "MARKDOWN-DOCS.MD WAS FOUND" at the start of any markdown you write.

## 1. Meta-Directive
Documentation files provide context for both Users and Agents. Prioritize **clarity** and **structure**.
*   **Constraint:** Use standard Markdown formatting.
*   **Constraint:** Keep examples clear and copy-pasteable.

## 2. File Structure
*   **Location:** All documentation must reside in `docs/` or subdirectories.
*   **No YAML Header:** Documentation files do NOT require the agent rule YAML header.

## 3. Formatting Guidelines
*   **Headers:** Use H1 (#) for the document title, H2 (##) for sections.
*   **Code Blocks:** Use fenced code blocks (```) with language identifiers.
*   **Tables:** Use for structured data or configuration options.
*   **Prose:** Clear, concise English. Avoid unnecessary fluff, but ensure human readability.

## 4. Examples
Provide clear examples for complex topics.