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
3. Members can search 30+ exercises by name, target/secondary muscle, movement
   pattern, or equipment. Every exercise includes labelled start/finish images,
   numbered instructions, coaching cues, common mistakes, and connected
   equipment or difficulty variations.
4. **Start guided workout** opens a focused session. The member records an
   optional working weight, completes sets, uses the automatic rest timer, and
   moves between exercises. An in-progress draft is stored per member and gym so
   it can be resumed after an interruption or mobile process termination.
5. Finishing writes a member-owned `workout_logs` document containing timing,
   goal, exercises, target/completed sets, repetitions, and weight.
6. Trainer-authored `workout_assignments` remain visible above self-guided
   workouts. The next trainer iteration should replace free-text routines with
   structured exercises and revisions.

Writes require connectivity. Firebase Storage is the primary origin for core
guidance media and `cached_network_image` keeps viewed images on-device. Resolved
URLs are stored per Firebase project so cached workouts survive app restarts.
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
4. Workout calendar, exercise charts, volume by muscle group, streaks, records,
   adherence, and trainer timeline.
5. Media compression, Hindi localization, and accessibility review.
6. Health Connect and HealthKit only after the core manual workout flow is
   reliable and privacy controls are complete.
