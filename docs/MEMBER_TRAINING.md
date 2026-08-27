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
3. Members can search by exercise, target muscle, or equipment and open paired
   start/end images with concise form guidance.
4. **Start guided workout** opens a focused session. The member records an
   optional working weight, completes sets, uses the automatic rest timer, and
   moves between exercises.
5. Finishing writes a member-owned `workout_logs` document containing timing,
   goal, exercises, target/completed sets, repetitions, and weight.
6. Trainer-authored `workout_assignments` remain visible above self-guided
   workouts. The next trainer iteration should replace free-text routines with
   structured exercises and revisions.

Writes require connectivity. Previously cached catalog images and Firestore
records provide graceful read behavior when available.

## Exercise content and licensing

The initial catalog uses selected records and paired images from
[`yuhonas/free-exercise-db`](https://github.com/yuhonas/free-exercise-db), pinned
to commit `b0eed061e1c832b3ed815fbaa4b45b3cdc14df49`. Its license dedicates the
dataset to the public domain. The app still identifies the source for
traceability.

Commercial exercise apps and design galleries are research references only.
Do not copy their code, screenshots, videos, branding, text, or layouts.

For production scale, import reviewed catalog records and compressed images
into platform-managed Firebase data/storage instead of depending indefinitely
on GitHub raw-content URLs. Each item should keep source, license, source
revision, reviewer, and safety-review metadata.

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
5. Platform-managed exercise import, media compression, Hindi localization, and
   accessibility review.
6. Health Connect and HealthKit only after the core manual workout flow is
   reliable and privacy controls are complete.
