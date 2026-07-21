# PROCEDURES/social-ads.md

## Purpose

Define how OpenClaw writes, organizes, and delivers Facebook and Instagram ad drafts for the credit repair business.

---

## What OpenClaw Does

OpenClaw writes all ad copy and saves drafts for human review. When the Meta Ad Publisher workflow is configured, OpenClaw can also trigger hands-free publishing directly to Facebook and Instagram via the Meta Marketing API.

- Without Meta API setup: OpenClaw drafts copy → owner copies into Meta Ads Manager manually
- With Meta API setup: OpenClaw drafts copy → owner approves → OpenClaw triggers webhook → n8n publishes automatically

See `admin/META_AD_PUBLISHER_SETUP.md` for the full hands-free publishing setup.

---

## Ad Output Location

All ad drafts are saved to:
`clients/credit-repair-co/OUTPUTS/drafts/ads/`

File naming:
```
facebook-ads-[campaign-name]-[date].md
instagram-ads-[campaign-name]-[date].md
```

---

## Ad Components OpenClaw Produces

For every ad set, OpenClaw will produce:

1. **Primary text** — the main body of the ad (125 characters recommended, 500 max)
2. **Headline** — short punchy line below the image (27 characters recommended)
3. **Description** — supporting line under the headline (27 characters recommended)
4. **Call to action** — button label (e.g., Learn More, Get Quote, Contact Us)
5. **Image prompt** — written description for Canva or AI image generation tool
6. **Audience targeting brief** — who to target in Meta Ads Manager
7. **A/B variations** — minimum 2 versions per ad for testing

---

## Campaign Types

### Campaign 1 — Awareness (Cold Audience)

Goal: Introduce the business to people who don't know it exists yet.

Target audience:
- Age 25–55
- Interests: personal finance, debt relief, budgeting, credit repair, debt consolidation
- Location: [target city/region]
- Exclude: existing customers

Tone: Empathetic, non-pushy, educational

Example primary text:
> "Carrying $10,000 or more in credit card or personal loan debt? You're not stuck. There are legal options to get out faster than you think — and it starts with a free conversation. No pressure, no commitment."

Example headline:
> "Free Debt Relief Consultation"

Example CTA: Learn More

---

### Campaign 2 — Problem / Solution (Warm Audience)

Goal: Speak directly to the pain point and offer a clear next step.

Target audience:
- People who visited the website or engaged with previous ads (retargeting)
- Lookalike audience based on enrolled clients (once available)

Tone: Direct, solution-focused

Example primary text:
> "Already in a debt consolidation program but still feel like you're not getting ahead? You may have options you haven't been told about. We help people with $10K+ in debt find a faster path forward. Free review — no obligation."

Example headline:
> "Is Your Debt Plan Actually Working?"

Example CTA: Get Quote

---

### Campaign 3 — Social Proof (Warm / Hot Audience)

Goal: Build trust with people who are considering but haven't acted yet.

Target audience:
- Website visitors who did not convert
- People who clicked previous ads but did not fill out the form

Tone: Reassuring, credibility-building

Example primary text:
> "We've helped people just like you go from $14,000 in debt to a clear financial path — legally, without bankruptcy. See how the process works and what it could mean for your situation."

Example headline:
> "Real Results. Real People."

Example CTA: Learn More

---

### Campaign 4 — Direct Response (Hot Audience)

Goal: Convert people who are ready to take action now.

Target audience:
- People who visited the contact or intake page but did not submit
- People who engaged with 3+ pieces of content

Tone: Urgent, clear offer

Example primary text:
> "Still carrying that debt? This week we're offering free credit and debt reviews — no cost, no commitment. Spots are limited. If you have $10K or more in debt, let's talk."

Example headline:
> "Free Review — Limited Spots"

Example CTA: Contact Us

---

## Image Prompt Guidelines

OpenClaw will write image prompts in this format for use with Canva, Adobe Firefly, or DALL-E:

```
Image prompt: [Description of visual]
Style: [Clean / professional / warm / bold]
Colors: [Suggested palette]
Text overlay: [Any text to appear on the image]
Avoid: [Anything that should not appear]
```

Example:
```
Image prompt: A person sitting at a kitchen table looking relieved, holding papers,
with a laptop open showing a positive financial chart. Natural lighting, home setting.
Style: Warm, approachable, hopeful
Colors: Blues and greens — convey trust and growth
Text overlay: "There's a way out."
Avoid: Stressed expressions, red colors, anything that looks predatory or salesy
```

---

## A/B Testing Instructions

For every campaign, OpenClaw produces a minimum of 2 variations:

- **Version A** — leads with the problem (pain-focused hook)
- **Version B** — leads with the solution (outcome-focused hook)

Run both for 7 days with equal budget. Keep the version with the lower cost per click / higher click-through rate. Report results to OpenClaw and it will write the next iteration based on what performed better.

---

## Weekly Ad Drafting Schedule

When instructed, OpenClaw will:

1. Review current campaign performance notes provided by the owner
2. Draft new ad variations based on what is working
3. Draft fresh creative for any campaign running longer than 3 weeks (ad fatigue)
4. Save all drafts to `OUTPUTS/drafts/ads/`
5. Flag any ad that may have compliance concerns before the owner reviews

---

## What the Owner Does

1. Reviews drafts in `OUTPUTS/drafts/ads/`
2. Approves, edits, or requests a revision
3. Copies approved copy into Meta Ads Manager
4. Sets budget, schedule, and launches
5. Reports performance back to OpenClaw for next iteration

---

## Compliance Reminder

All ad copy must comply with CROA and Meta's financial services advertising policies.

Never include in any ad:
- Guaranteed credit score improvements
- Specific outcome promises ("We'll remove all negative items")
- Before/after credit score claims without proper disclaimers
- Anything that implies the business can create a new credit identity

Meta also requires financial service advertisers to comply with its Special Ad Category rules for credit. Select "Credit" as the Special Ad Category in Meta Ads Manager — this affects available targeting options.

All ad drafts require human review before publishing.
