# Research

Structured research on various topics.

## Philosophy

Each topic gets its own folder. Research happens in two phases: gather everything into background notes, then distill into a final report. This separation keeps the mess of research separate from the clean output.

## Structure

```
{topic}/
├── requirements.md    # User constraints and context (if needed)
├── background.md      # Raw research notes, citations, excerpts
└── report.md          # Final distilled writeup
```

For comparison research (evaluating multiple options):

```
{topic}/
├── research_overview.md   # Criteria, sources, methodology
├── {option_1}.md          # Notes on each option
├── {option_2}.md
└── comparison_report.md   # Final analysis
```

## Requirements Gathering

If the research topic is ambiguous or has unstated constraints, clarify before diving in.

1. **Ask probing questions** - Short list, focused on what will shape the research
2. **Create requirements.md** - Capture the answers so they don't get lost
3. **Then start research** - Now you know what you're actually looking for

Examples of things to clarify:
- Budget or price constraints
- Must-have vs nice-to-have features
- Timeline or urgency
- Specific use case or context
- Who the output is for

Skip this step if the request is already clear and specific.

## Research Phase

### Workflow

1. **Create the background file first** - Before any research, create the file
2. **Research one aspect at a time** - For each topic, research sources, consolidate, then write
3. **Add findings immediately** - Edit the background file after each source
4. **Cite sources** - Within a topic, note which source each fact came from
5. **Repeat** - Build incrementally; this lets you steer as you go

### How to Search

1. **Use open-ended queries** - Don't pre-specify expected answers
2. **Prioritize quality sources** - Target reputable sites for the domain (journals, official docs, expert forums)
3. **Run multiple searches** - Different angles surface different findings
4. **Note contradictions** - When sources disagree, capture both views
5. **Match source age to topic velocity**:
   - Fast-moving fields (tech, pricing, current events) → prioritize recent sources
   - Stable domains (history, established science) → older authoritative sources still valuable
   - Mixed topics → recent for current state, older for foundational context

### Adding to Background Files

- Organize by topic with `## Section` headers
- Bold key findings for scannability
- Use markdown reference-style links at the end of each section
- Include publication/source in link text: `([Source: Title][1])`
- Preserve nuance—don't flatten "debated" into "confirmed"

## Report Phase

### Executive Summary

Every report opens with a summary that answers the core question. The structure of the summary should be driven by the research topic itself—what matters depends on what you're researching.

- Lead with the conclusion or recommendation
- Include the key details that support it
- Keep it dense but readable—no filler, no throat-clearing

### Comparison Tables

Use tables when comparing options across objective factors. Good candidates:

- Pricing tiers
- Feature presence/absence
- Measurable specs
- Support for specific integrations

Avoid tables for subjective assessments (ease of use, quality, value). Those belong in prose where you can explain the reasoning.

### Tone

Write for a general audience while preserving rigor. Engaging without being overblown—no breathless superlatives but also no dry recitation. Let the material carry the interest.

- **Accessible** - Avoid jargon; when technical terms are necessary, provide context
- **Grounded** - Stick to what the evidence supports; flag uncertainty honestly
- **Restrained** - Trust the reader; no hype, no hedging everything into mush

### Workflow

1. Gather research in background files
2. Identify the core question the report answers
3. Distill into final report with summary up front
4. Add comparison tables where objective factors allow
5. Keep it concise—shorter is usually better
