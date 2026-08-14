// Example: Call for Proposals rendered with the AP-LS brand template
// ==================================================================
// This demonstrates the general-purpose apls-template.typ for a
// conference CFP. The same template works for any AP-LS document.
//
// COMPILE
//   typst compile example-cfp.typ cfp-2027.pdf
//
// WATCH (auto-rebuild on save)
//   typst watch example-cfp.typ cfp-2027.pdf

#import "apls-template.typ": apls-doc, apls-button, apls-rule, apls-two-col

#show: apls-doc.with(
  title: "2027 Call for Proposals",
  subtitle: "Annual Conference of the American Psychology-Law Society",
  authors: ("AP-LS Conference Committee",),
  date: "March 18–20, 2027  ·  Louisville, Kentucky",
  logo: true,
  header-title: "AP-LS 2027 CFP",
  toc: false,
)

// ── Conference Overview ───────────────────────────────────────────────

= Submission Invitation

We invite proposal submissions for the #strong[2027 Annual Conference of AP-LS]. We strongly encourage empirically based proposals, proposals that involve new and emerging topics within psychology and law, and proposals that incorporate historically marginalized or underrepresented populations.

Proposals will be evaluated through a blind review process focused on intellectual merit, innovation, novelty, and integration of multiple aspects of the field.

#apls-rule

// ── Session Types ─────────────────────────────────────────────────────

= Session Types

== Symposia

A single topic coordinated group of presentations with a minimum of 3 and maximum of 5 presentations and an independent discussant. The participation of each presenter should be secured before submission. Submissions are limited to:

- A 200-word abstract for the symposium session
- 3–4 overarching learning objectives
- A 100-word abstract plus 1,000-word summary for each paper
- CVs for each presenter

All symposia material must be proposed in a #strong[single submission].

== Papers

Presentation of a paper describing an individual research topic OR piece of legal scholarship. Submissions are limited to:

- A 100-word abstract
- 1,000-word summary
- 1–2 learning objectives

== Data-Blitz

A 5-minute presentation (limit 3 slides) covering a bite-sized piece of psycho-legal research. Submissions are limited to:

- A 100-word abstract
- 1,000-word summary
- 1–2 learning objectives

Sessions offer a fast-paced overview of exciting emerging research. Data-blitz sessions will not be organized by topic.

== Posters

Posters are presented in written format on display boards at one of two poster sessions held Friday and Saturday evenings. Submissions are limited to:

- A 100-word abstract
- 1,000-word summary

We encourage poster presenters to use a #link("https://convention.apa.org/blog/rethinking-the-science-poster")[Better Poster format].

== Projects-in-Progress

Authors can submit a "project in progress" to present a project in the conceptualization, pilot testing, and/or preliminary implementation phase. The purpose is to present an early project idea and receive feedback from conference colleagues regarding roadblocks, considerations, and areas for potential collaboration.

Submissions are limited to a 100-word abstract, 1,000-word summary, and 1–2 learning objectives. Projects in progress will be limited to 2–3 similarly themed projects per session.

// ── Important Information ─────────────────────────────────────────────

= Submission Limits & Policies

Authors will indicate when submitting whether they would like their proposal to be considered as a:

+ Paper
+ Data-blitz
+ Poster
+ Any combination of these

There is a limit of #strong[TWO] first-author symposia/paper/data-blitz submissions per person and #strong[ONE] Project in Progress.

There are #strong[no limits] for the number of submissions for posters or appearances as a discussant or session chair.

#apls-rule

// ── Submission Details ────────────────────────────────────────────────

= How to Submit

All proposals must be submitted through the conference submission portal.

#apls-two-col(
  [
    #strong[Deadline]
    
    Submissions close at 11:59 PM ET.
    
    Late submissions will not be accepted.
  ],
  [
    #strong[Portal]
    
    Visit the submission portal to register, submit your proposal, AND sign up as a reviewer.
  ],
)

// ── Reviewers ─────────────────────────────────────────────────────────

= Reviewers Wanted

Reviewers are invited for all content areas including both professional and graduate student reviewers. Proposals will be distributed for review in early November.

Please sign up to be a reviewer using the submission portal when you submit your proposal, or, if you do not plan to submit a proposal, using the reviewer sign-up form.

// ── Contact ───────────────────────────────────────────────────────────

= Questions?

If you have any questions about the call for proposals, please contact the conference co-chairs at #link("mailto:conference@ap-ls.org")[conference@ap-ls.org].

#align(center, [
  #v(2em)
  #text(font: "Cormorant Garamond", size: 12pt, style: "italic", [
    Looking forward to seeing everyone in Louisville!
  ])
  #v(0.5em)
  #text(size: 10pt, fill: rgb("#737475"), "2027 AP-LS Conference Co-Chairs")
])
