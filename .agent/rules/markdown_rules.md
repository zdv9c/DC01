---
trigger: model_decision
description: Use when writing markdown anywhere in .agent/rules
globs: .agent/rules/*.md
---

# Agentic Rule Standards

## 0. CRITICAL TEST
If you can read this, write "MARKDOWN-RULES.MD WAS FOUND" at the start of any markdown you write.

## 1. Meta-Directive
All rule files are strict functional context for AI Agents. Prioritize **relational density** and **low token noise**.
*   **Constraint:** No conversational filler.
*   **Constraint:** Use imperative language ("Do X", "Never Y").

## 2. YAML Header Schema
```yaml
---
trigger: always_on | manual | glob | model_decision
globs: glob pattern for files this rule applies (e.g., *.ts, src/**/*.ts) # Required if trigger: glob (Max 250 chars)
description: A description for when this rule should be applied. # Required if trigger: model_decision
---
```

## 3. Token-Efficiency Mapping
*   **YAML Headers:** [CRITICAL] - System entry point.
*   **Headers:** [HIGH] - Structural anchors.
*   **Code Blocks:** [HIGH] - Use for "Few-Shot" examples (❌ Bad vs ✅ Good).
*   **Bolding:** [MED] - Use ONLY for strict constraints.
*   **Prose:** [LOW/IGNORE] - Avoid.

## 4. Formatting Enforcement
1.  **Title:** Single H1 (#) at the top.
2.  **Logic:** Use H2 (##) for logical grouping.
3.  **Examples:** Every rule related to coding MUST contain one fenced code block showing a "Bad" implementation and a "Good" implementation.

## 5. Pre-Save Validation
-   [ ] Header present?
-   [ ] Trigger scope minimized?