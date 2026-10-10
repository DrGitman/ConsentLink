# ConsentLink usability test script

Use this script for both planned usability-test rounds. Round 1 is a formative
baseline; Round 2 repeats the same tasks after the agreed design changes. The
P4 work package plans five users for Round 1. Record the actual number and
participant groups for each round; do not imply a group was represented if it
was not recruited.

## Before the session

- Confirm the study team's required ethics or course approval and obtain
  informed consent for the usability session.
- Use only the approved test build and synthetic sample files. Do not enter
  real study, participant, contact, ethics-reference, or consent information.
- Record the build/version, device, test date, round, task order, and whether
  the session was remote or in person.
- Assign a random session code. Do not create a key linking it to a person's
  identity.
- Ask permission before taking notes. Do not record audio, video, signatures,
  contact details, or other identifying information.
- If language accessibility is being tested, ask which interface language
  they would like to use. Record only a language code if needed, not personal
  background or fluency history.
- Check that the relevant language, read-aloud, accessibility, and prototype
  states are available. Record unavailable or simulated behaviours as
  limitations; do not present a preview as a working backend feature.

## Session record

| Field | Entry |
|---|---|
| Random session code | |
| Round (1 baseline / 2 retest) | |
| Date and test build/version | |
| Device / display size | |
| Broad participant role (optional; no identifying detail) | |
| Interface language code (optional) | |
| Moderator code | |
| Observer code (optional) | |
| Consent to usability session confirmed | Yes / No |

Do not begin if usability-session consent has not been confirmed. Store any
required consent record separately from these anonymized notes, following the
approved study procedure.

## Opening script

> Thank you for taking part. We are testing ConsentLink, not testing you. Some
> screens may be prototypes or use sample data; not every control or service is
> connected. Please use only the sample information provided. You can stop or
> skip any task at any time. I may take anonymous notes about what works and
> where the interface is confusing, but I will not record your name or record
> audio or video. Please think aloud if you are comfortable. Do you have any
> questions before we begin?

Confirm consent before continuing. Do not coach during a task. If the
participant asks what to do, say: “What would you expect to do next?”

## Task procedure

Use the same task wording and order in both rounds where possible. For each
task, record outcome, time to completion, assistance, and an anonymized
observation. Stop timing when the participant says they are done or reaches
the defined success state. Do not count a task as successful solely because a
moderator completed it for them.

Suggested 45-minute session: 5 minutes for welcome and consent, 25 minutes for
tasks, 5 minutes for the Round 2 SUS questionnaire, and 10 minutes for the
debrief. Adjust timing without rushing participants. Administer the SUS after
all Round 2 tasks and before open-ended debrief questions. Round 1 is formative
unless the team has explicitly agreed to collect SUS in both rounds.

| # | Read aloud to participant | Success criteria | Neutral follow-up if stuck |
|---|---|---|---|
| 1 | “You want to read this consent information in the language you prefer. Show me how you would choose a language and listen to the information.” | Finds language selection and read-aloud controls, or accurately identifies that a control is unavailable in this build. | “Where would you look for language or listening options?” |
| 2 | “Using the sample consent information, tell me what the study is about, one possible risk, and what you could do if you did not want to take part or later wanted to stop.” | Explains the purpose and at least one risk in their own words, and understands participation is voluntary and can be stopped. | “What would you want to know before deciding?” |
| 3 | “A researcher has a sample proposal and wants to start preparing a consent form. Show me how you would begin and tell me what you expect to happen to the file.” | Starts the proposal flow and can distinguish a working action from a preview, notice, or unconnected control. | “What makes you think the file has or has not been uploaded?” |
| 4 | “You are reviewing a draft. Find any item that still needs attention, then show how you would approve or edit a section.” | Locates a missing item, distinguishes approval from editing, and can identify the resulting status. | “How would you check whether this draft is ready to continue?” |
| 5 | “The draft is in another language. Show me how you would decide whether its translation is ready to use.” | Recognizes that a fluent human reviewer must verify a translation when required; does not assume AI output alone is approved. | “Who do you think should check this translation?” |
| 6 | “Imagine you are interrupted while reviewing. Show what you would do to leave safely and return to the work.” | Returns to the task without losing or misrepresenting its state, or identifies that recovery is not supported in the tested build. | “What would you expect to see when you return?” |

If a task depends on a screen or feature that is absent from the test build, mark
it **Not testable** and record the build limitation. Do not count an imagined
feature as implemented.

## Per-task observation sheet

Copy one table per session.

| Task | Outcome (success / partial / not successful / not testable) | Time (seconds) | Assistance (none / neutral prompt / direct help) | Misstep or recovery | Anonymous observation |
|---|---|---:|---|---|---|
| 1. Language and listening | | | | | |
| 2. Understanding and rights | | | | | |
| 3. Start proposal flow | | | | | |
| 4. Review and approval | | | | | |
| 5. Translation sign-off | | | | | |
| 6. Interruption and recovery | | | | | |

### Comprehension check

Record the participant's answer in a short, non-identifying paraphrase. Do not
write names, verbatim personal stories, or details that could identify a
person or study.

| Check | Correct / partly correct / not understood | Anonymous note |
|---|---|---|
| Can explain the study purpose | | |
| Can describe a risk or discomfort | | |
| Understands participation is voluntary | | |
| Knows they can stop or withdraw | | |
| Understands who checks a translation | | |

### End-of-session questions

- What was easiest to understand?
- Where did you hesitate or feel unsure?
- Was there anything you expected to be able to do but could not?
- What would you change first?
- Is there anything else you want the team to know?

Do not ask for personal health, research, or other sensitive experiences.
Thank the participant and remind them that their feedback is about the design,
not their performance.

## Round summary

Complete one summary per round. Report counts with denominators (for example,
“3/5 completed task 1 without help”). Keep roles broad and suppress breakdowns
that could identify someone in a small group. Separate observations from
interpretations and recommendations.

| Measure | Result |
|---|---|
| Number of sessions completed | |
| Participant groups represented (broad categories only) | |
| Build/version tested | |
| Tasks successful without help / attempted | |
| Tasks requiring prompts / attempted | |
| Tasks not testable | |
| Comprehension checks correct / assessed | |
| Most frequent usability issue | |
| Design change to test next | |
| Limitations (sample, build, language, or environment) | |

Do not claim statistical significance or broad fairness from a small usability
sample. For fairness analysis, compare language groups only when there are
enough observations to avoid identifying individuals; report small or missing
groups as limitations rather than treating absence of data as equal outcomes.
