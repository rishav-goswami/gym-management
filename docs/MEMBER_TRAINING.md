# Member training experience

The member product combines three proven patterns without copying a commercial
app's visual design or proprietary media:

- guided, goal-based sessions and approachable movement instruction;
- quick set completion, rest timing, and workout history;
- trainer-assigned plans, gym context, attendance, membership, and support.

## Current member flow

1. **Home** shows membership health, today's recommended session, this week's
   completed workouts/sets, gym announcements, and trainer support.
2. **Training** lets the member choose Build muscle, Get stronger, Lose weight,
   Improve fitness, or Move better.
3. **Profile** collects goal, experience, weekly schedule, available equipment,
   optional limitations and a private tenant-scoped profile image. Home uses
   the first selected goal for its general recommended session.
4. Members can search 30+ exercises by name, target/secondary muscle, movement
   pattern, or equipment. Every exercise includes labelled start/finish images,
   numbered instructions, coaching cues, common mistakes, and connected
   equipment or difficulty variations.
5. **Start guided workout** opens a focused session. The member records an
   optional working weight, completes sets, uses the automatic rest timer, and
   moves between exercises. An in-progress draft is stored per member and gym so
   it can be resumed after an interruption or mobile process termination.
6. Finishing writes a member-owned, version-two `workout_logs` document
   containing timing, goal, and per-exercise detail: target/completed sets, a
   per-set `sets` array (matching the routine logger's schema), plus
   compatibility summary fields (completed reps per set, working weight) for
   older clients. That log is the source for the member's training progress.
7. Trainer-authored `workout_assignments` remain visible above self-guided
   workouts. The next trainer iteration should replace free-text routines with
   structured exercises and revisions.
8. Exercise details, personal routines and gym assignments expose **Ask
   trainer** when the consumer has a connected gym. The support request includes
   only the stable exercise/routine/assignment reference. A primary trainer is
   shown in the gym profile; when none is available, the request enters a
   permission-scoped trainer queue that one trainer can claim atomically.

Technique support remains asynchronous general coaching. Trainers do not
receive private workout logs, measurements, limitations or progress photos from
opening a request. A member may voluntarily describe or attach relevant context
and can stop sharing any personal projection independently of the support case.

### Member-created routines and free logging

Members can create reusable `member_routines` for any combination of weekdays,
edit or delete them, and start a new log from a routine. **Log today's workout**
also supports an unplanned session without creating a template first.

Each movement chooses a tracking contract:

- strength: independent weight and reps for every set;
- bodyweight: reps and optional added load for every set;
- cardio: one or more intervals with duration, speed, incline, distance, and
  optional added load;
- timed movement: duration and optional added load.

Catalog exercises retain their stable exercise ID. Custom movements receive a
stable ID when added to a routine, allowing later sessions to stay grouped in
Progress. Version-two workout logs retain the detailed `sets` array while also
writing compatibility summary fields for older clients.

## Connected progress

The member **Progress** area follows established strength-tracker information
patterns without copying another product's visual design:

- **Overview** summarizes the latest 28 days, eight-week workout consistency,
  training time, completed sets, estimated lifted volume, recent sessions, and
  the latest body snapshot. Members can set a target-weight goal from their
  latest logged weight; progress toward it is tracked in a member-owned
  `goals` document and shown as a progress bar until the member updates it,
  marks it achieved, or removes it.
- **Exercises** groups workout-log entries by stable exercise ID. Each exercise
  exposes its guidance image, history, best working weight, estimated one-rep
  maximum, best session volume, bodyweight rep records, or cardio time/speed/
  incline/distance. This is the primary link between exercise guidance and
  progress.
- **Body** charts weight and optional body-fat history and reads private progress
  photos through authenticated Firebase Storage rather than public URLs.

Estimated volume is `sets × completed reps × working weight`. Estimated 1RM uses
the Epley formula as a trend indicator; the UI explicitly avoids presenting it
as an instruction to attempt a maximal lift. Older workout logs that contain
only a textual target rep range remain readable, while new logs record the
member-entered completed reps.

Product references: Strong's official exercise detail model connects guidance,
history, charts, and records; Hevy's official documentation differentiates
weighted, bodyweight, duration, and cardio performance metrics. We adopt the
information architecture, not their branding, copy, screenshots, or layouts.

Writes require connectivity. Firebase Storage is the primary origin for core
guidance media and `cached_network_image` keeps viewed images on-device. Resolved
URLs are stored per Firebase project so cached workouts survive app restarts.
Flutter Web also requires the tracked bucket CORS policy installed by
`npm run storage:cors`; without it, the browser can receive the object but cannot
decode it for the app. If Storage URL resolution or delivery fails, the image
widget retries the pinned source before showing its final dumbbell placeholder.
Firestore uses a bounded 100 MB persistent cache.

## Exercise content and licensing

The initial catalog uses 34 selected records and 68 paired images from
[`yuhonas/free-exercise-db`](https://github.com/yuhonas/free-exercise-db), pinned
to commit `b0eed061e1c832b3ed815fbaa4b45b3cdc14df49`. Its license dedicates the
dataset to the public domain. The app still identifies the source for
traceability.

Commercial exercise apps and design galleries are research references only.
Do not copy their code, screenshots, videos, branding, text, or layouts.

The versioned `firebase/data/exercise-media.v1.json` manifest and
`npm run catalog:sync` command provision identical paths and source/license
metadata into any Firebase project. The pinned GitHub URLs remain a temporary
bootstrap fallback, not the preferred production origin. This keeps the app
binary small while making the initial catalog account-portable.

## Safety boundary

The app provides general educational exercise guidance, not diagnosis,
rehabilitation, or individualized medical advice. It tells members to use
manageable loads, stop for pain/dizziness/unusual discomfort, and consult their
trainer or a qualified healthcare professional when appropriate.

Before broad release, a qualified fitness professional should review the
exercise selection, contraindications, progressions/regressions, and India-first
localization. The product must not estimate calories or prescribe intensity from
health conditions without validated inputs and an explicit safety design.

## Next iterations

1. Structured trainer templates and assignments with substitutions and revision
   history.
2. Previous-set values, RPE/RIR, warm-up/drop/failure sets, supersets, notes,
   plate calculator, and personal-record detection.
3. Goal onboarding using experience, weekly schedule, available gym equipment,
   injuries/limitations, and preferred session length.
4. Workout calendar, volume by muscle group, richer set-level logging, streaks,
   and trainer-visible adherence/timeline views.
5. Media compression, Hindi localization, and accessibility review.
6. Health Connect and HealthKit only after the core manual workout flow is
   reliable and privacy controls are complete.
