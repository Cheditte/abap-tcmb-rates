# SAP Community author outline — one-report TCMB loader

**Unpublished planning notes, not a ready-to-paste post.** The author should explain their own observations in their own voice and check the [current SAP Community GenAI guidelines](https://community.sap.com/t5/welcome-corner-knowledge-base/guidelines-for-content-created-with-generative-ai/ta-p/14238551) before publication. No post is published by this change.

## Publication prerequisites

- Complete relevant [SAP acceptance](../CONTRIBUTING.md#sap-acceptance-checklist) on the exact source hash. Separate personal observations from handoff reports.
- Identify ABAP 7.00 as a syntax target; do not claim older-system runtime support from 7.58 activation or lint.
- Capture sanitized actual selection-screen, preview, real-write/OB08 and conversion-readback evidence. Never present diagrams or old settings/installer screenshots as current GUI proof.
- Link the released/approved revision once available; this is still a pre-release integration candidate.

## Suggested structure

1. Begin with the use: read TCMB rates in SAP, choose fields/dates/currencies, preview, then verify records in OB08. Use the [overview illustration](images/overview-en.svg).
2. Explain the three preparations: developer access, FI choices and SAP-server HTTPS. Use the [preparation illustration](images/prepare-en.svg).
3. Demonstrate one-file SE38 upload, fixed-point arithmetic, long-line settings and activation. Explain that variants store selections; there are no custom profile tables. Use the [setup illustration](images/setup-en.svg).
4. Show a limited trial: one published day, USD/JPY, the agreed SAP rate type, explicit date rule, Keep existing and Test run. Do not imply sample M is an accounting recommendation.
5. Explain JPY units/OBBS ratios and verify actual conversions. Compare planned NEW with an actual write and equal UNCHANGED rerun.
6. Discuss missing HTTP bulletins versus file errors, partial commits and recovery, daily variants/jobs and restricted users.
7. State exactly what was tested and invite focused feedback on the remaining acceptance cases.

Use [the guide](../WALKTHROUGH.md), [technical reference](../TECHNICAL.md) and [validation record](validation-v0.3.0.md) as the factual basis. Extensions are local LCL_EXIT methods; the former global-class API is not available in this edition.
