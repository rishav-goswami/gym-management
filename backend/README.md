# 🏋️ Gym Management Flutter App - Full Feature & Flow Design

---

## ✨ Overview

A Flutter-based mobile app with role-based dashboards for **Admin**, **Trainer**, and **User**. The backend is powered by **Express.js + TypeScript** and **MongoDB** for scalable, document-driven flexibility. The app offers gym management, workout planning, user tracking, and communication features.

---

## 🛠️ Technology Stack

* **Frontend:** Flutter

  * Material Design Widgets
  * flutter\_bloc for state management
  * flutter\_chat\_ui for chat feature
  * fl\_chart for visual tracking

* **State Management:** flutter\_bloc

  * AuthBloc
  * UserBloc
  * TrainerBloc
  * AdminBloc

* **Backend:** Node.js (Express) + TypeScript

  * REST API
  * Socket.io for real-time chat
  * JWT-based authentication

* **Database:** MongoDB

  * Mongoose ODM
  * Role-based document modeling

* **Authentication:** JWT with Role-based Access

  * Middleware for route protection
  * Refresh token mechanism (optional in v2)

* **Realtime Chat:** Socket.IO

  * Private messaging between user and trainer
  * Chat history persistence

---

## 🌐 Roles & Functional Scope

### ✉️ Common Features

* **Authentication:** Secure login/signup with validations
* **Role-based Routing:** Redirect user based on assigned role
* **Profile View & Edit:** Change profile image, contact info, password
* **Chat Support:** Real-time communication using chat UI
* **Logout:** Token-based session termination

### 👨‍🏋️ User Flow (Gym Member)

* Register account (with optional referral code or plan)
* Log in and land on user dashboard
* View assigned trainer info and initiate chat
* Daily view of:

  * Exercise routine (day-wise)
  * Diet plan (meal-wise)
* Log performance:

  * Weight updates
  * Calories burned
  * Notes
* Visual graphs for weight/calories over time
* View subscription info and renewal history
* Push notifications for plan updates, chat replies, diet/workout changes

### 👩‍🏋️ Trainer Flow

* Log in and land on trainer dashboard
* View list of assigned users
* Assign or update workout plan for each user:

  * Day-wise routine
  * Exercise notes or links to YouTube videos
* Assign or update diet plan per user:

  * Meal breakdown (Breakfast, Lunch, Dinner)
  * Nutrition info (optional)
* View user progress charts
* Chat directly with each user
* Track last activity or interaction time for each user

### 🧑‍💼 Admin Flow

* Admin login with credentials (email/password)
* Access dashboard:

  * Total users, trainers, subscriptions
  * Revenue tracking
* Manage user list:

  * View all users
  * Assign/replace trainer
  * View subscription status
  * View user health goals
* Manage payments:

  * View all payment records
  * Filter by method, user, date
  * Export to CSV/Excel
* View trainer activity (last login, assigned users count)

---

## 📁 Backend MongoDB Data Model Design

### 1. User

```ts
interface User {
  _id: ObjectId,
  name: string,
  email: string,
  password: string,
  role: 'user' | 'trainer' | 'admin',
  profileImage?: string,
  trainerId?: ObjectId,
  healthGoals: string,
  subscription: Subscription,
  performance: PerformanceLog[],
  createdAt: Date,
  updatedAt: Date
}
```

* Auth users based on role
* Used by Admin to assign trainers
* Trainer can access `healthGoals`

### 2. Trainer

```ts
interface Trainer {
  _id: ObjectId,
  name: string,
  email: string,
  password: string,
  assignedUsers: ObjectId[],
  profileImage?: string,
  createdAt: Date,
  updatedAt: Date
}
```

* Trainers have multiple users
* Used in reporting and chat pairing

### 3. WorkoutRoutine

```ts
interface WorkoutRoutine {
  _id: ObjectId,
  userId: ObjectId,
  days: [
    {
      day: string,
      exercises: string[],
    }
  ],
  createdBy: ObjectId,
  createdAt: Date
}
```

* One routine per user per week
* Trainer-defined

### 4. DietPlan

```ts
interface DietPlan {
  _id: ObjectId,
  userId: ObjectId,
  dayWiseDiet: [
    {
      day: string,
      meals: string[],
    }
  ],
  createdBy: ObjectId,
  createdAt: Date
}
```

* Meal structure defined by trainer

### 5. Subscription

```ts
interface Subscription {
  isActive: boolean,
  startDate: Date,
  endDate: Date,
  paymentMethod: 'UPI' | 'Card' | 'Cash',
  amountPaid: number
}
```

* Directly embedded in user object for faster access

### 6. PaymentHistory

```ts
interface PaymentHistory {
  _id: ObjectId,
  userId: ObjectId,
  amount: number,
  method: 'UPI' | 'Card' | 'Cash',
  date: Date,
  remarks?: string
}
```

* Used for reports and admin views

### 7. PerformanceLog

```ts
interface PerformanceLog {
  date: Date,
  weight: number,
  caloriesBurned: number,
  notes?: string
}
```

* Added by user
* Visualized in performance screen

### 8. Chat

```ts
interface ChatMessage {
  _id: ObjectId,
  from: ObjectId,
  to: ObjectId,
  message: string,
  timestamp: Date,
  read: boolean
}
```

* Managed via WebSockets
* Shown in chat history screen

---

## 🛍️ Admin UI Flow

* **Dashboard**

  * Cards showing total users, trainers
  * Pie chart for payment methods
* **Customer List**

  * Search + filter (by trainer, status)
  * Click to view profile
* **Assign Trainer**

  * Dropdown select + assign action
* **Payment History**

  * Table view
  * Export/Download CSV
* **Trainer View**

  * List of trainers with assigned users count

---

## 🏋️ Trainer UI Flow

* **Dashboard**

  * Summary cards
  * Chart showing user engagement
* **Assigned Users**

  * List view
  * Tap to open user details
* **Create/Update Workout**

  * Form per day
  * Add notes/video link
* **Create/Update Diet**

  * Form for each meal per day
* **View Progress**

  * Charts
* **Chat**

  * Real-time conversation with users

---

## 🧜 User UI Flow

* **Dashboard**

  * Current diet plan
  * Today's exercise list (checkbox to mark done)
  * Performance summary
* **My Trainer**

  * Trainer info + message button
* **Track Progress**

  * Weight chart
  * Calories burned graph
* **Payment**

  * Current plan
  * History table
  * Renew button
* **Chat**

  * Trainer interaction

---

## 🌐 REST API Endpoints

### Auth

* `POST /api/auth/login` – Authenticate and return token
* `POST /api/auth/signup` – Register user
* `GET /api/auth/profile` – Get user info (JWT required)

### Users

* `GET /api/users/` – Admin only
* `PATCH /api/users/:id/assign-trainer` – Admin only

### Workouts
# 🏋️ Gym Management Flutter App - Full Feature & Flow Design

---

## ✨ Overview

A Flutter-based mobile app with role-based dashboards for **Admin**, **Trainer**, and **User**. The backend is powered by **Express.js + TypeScript** and **MongoDB** for scalable, document-driven flexibility. The app offers gym management, workout planning, user tracking, and communication features.

---

## 🛠️ Technology Stack

* **Frontend:** Flutter

  * Material Design Widgets
  * flutter\_bloc for state management
  * flutter\_chat\_ui for chat feature
  * fl\_chart for visual tracking

* **State Management:** flutter\_bloc

  * AuthBloc
  * UserBloc
  * TrainerBloc
  * AdminBloc

* **Backend:** Node.js (Express) + TypeScript

  * REST API
  * Socket.io for real-time chat
  * JWT-based authentication

* **Database:** MongoDB

  * Mongoose ODM
  * Role-based document modeling

* **Authentication:** JWT with Role-based Access

  * Middleware for route protection
  * Refresh token mechanism (optional in v2)

* **Realtime Chat:** Socket.IO

  * Private messaging between user and trainer
  * Chat history persistence

---

## 🌐 Roles & Functional Scope

### ✉️ Common Features

* **Authentication:** Secure login/signup with validations
* **Role-based Routing:** Redirect user based on assigned role
* **Profile View & Edit:** Change profile image, contact info, password
* **Chat Support:** Real-time communication using chat UI
* **Logout:** Token-based session termination

### 👨‍🏋️ User Flow (Gym Member)

* Register account (with optional referral code or plan)
* Log in and land on user dashboard
* View assigned trainer info and initiate chat
* Daily view of:

  * Exercise routine (day-wise)
  * Diet plan (meal-wise)
* Log performance:

  * Weight updates
  * Calories burned
  * Notes
* Visual graphs for weight/calories over time
* View subscription info and renewal history
* Push notifications for plan updates, chat replies, diet/workout changes

### 👩‍🏋️ Trainer Flow

* Log in and land on trainer dashboard
* View list of assigned users
* Assign or update workout plan for each user:

  * Day-wise routine
  * Exercise notes or links to YouTube videos
* Assign or update diet plan per user:

  * Meal breakdown (Breakfast, Lunch, Dinner)
  * Nutrition info (optional)
* View user progress charts
* Chat directly with each user
* Track last activity or interaction time for each user

### 🧑‍💼 Admin Flow

* Admin login with credentials (email/password)
* Access dashboard:

  * Total users, trainers, subscriptions
  * Revenue tracking
* Manage user list:

  * View all users
  * Assign/replace trainer
  * View subscription status
  * View user health goals
* Manage payments:

  * View all payment records
  * Filter by method, user, date
  * Export to CSV/Excel
* View trainer activity (last login, assigned users count)

---

## 📁 Backend MongoDB Data Model Design

### 1. User

```ts
interface User {
  _id: ObjectId,
  name: string,
  email: string,
  password: string,
  role: 'user' | 'trainer' | 'admin',
  profileImage?: string,
  trainerId?: ObjectId,
  healthGoals: string,
  subscription: Subscription,
  performance: PerformanceLog[],
  createdAt: Date,
  updatedAt: Date
}
```

* Auth users based on role
* Used by Admin to assign trainers
* Trainer can access `healthGoals`

### 2. Trainer

```ts
interface Trainer {
  _id: ObjectId,
  name: string,
  email: string,
  password: string,
  assignedUsers: ObjectId[],
  profileImage?: string,
  createdAt: Date,
  updatedAt: Date
}
```

* Trainers have multiple users
* Used in reporting and chat pairing

### 3. WorkoutRoutine

```ts
interface WorkoutRoutine {
  _id: ObjectId,
  userId: ObjectId,
  days: [
    {
      day: string,
      exercises: string[],
    }
  ],
  createdBy: ObjectId,
  createdAt: Date
}
```

* One routine per user per week
* Trainer-defined

### 4. DietPlan

```ts
interface DietPlan {
  _id: ObjectId,
  userId: ObjectId,
  dayWiseDiet: [
    {
      day: string,
      meals: string[],
    }
  ],
  createdBy: ObjectId,
  createdAt: Date
}
```

* Meal structure defined by trainer

### 5. Subscription

```ts
interface Subscription {
  isActive: boolean,
  startDate: Date,
  endDate: Date,
  paymentMethod: 'UPI' | 'Card' | 'Cash',
  amountPaid: number
}
```

* Directly embedded in user object for faster access

### 6. PaymentHistory

```ts
interface PaymentHistory {
  _id: ObjectId,
  userId: ObjectId,
  amount: number,
  method: 'UPI' | 'Card' | 'Cash',
  date: Date,
  remarks?: string
}
```

* Used for reports and admin views

### 7. PerformanceLog

```ts
interface PerformanceLog {
  date: Date,
  weight: number,
  caloriesBurned: number,
  notes?: string
}
```

* Added by user
* Visualized in performance screen

### 8. Chat

```ts
interface ChatMessage {
  _id: ObjectId,
  from: ObjectId,
  to: ObjectId,
  message: string,
  timestamp: Date,
  read: boolean
}
```

* Managed via WebSockets
* Shown in chat history screen

---

## 🛍️ Admin UI Flow

* **Dashboard**

  * Cards showing total users, trainers
  * Pie chart for payment methods
* **Customer List**

  * Search + filter (by trainer, status)
  * Click to view profile
* **Assign Trainer**

  * Dropdown select + assign action
* **Payment History**

  * Table view
  * Export/Download CSV
* **Trainer View**

  * List of trainers with assigned users count

---

## 🏋️ Trainer UI Flow

* **Dashboard**

  * Summary cards
  * Chart showing user engagement
* **Assigned Users**

  * List view
  * Tap to open user details
* **Create/Update Workout**

  * Form per day
  * Add notes/video link
* **Create/Update Diet**

  * Form for each meal per day
* **View Progress**

  * Charts
* **Chat**

  * Real-time conversation with users

---

## 🧜 User UI Flow

* **Dashboard**

  * Current diet plan
  * Today's exercise list (checkbox to mark done)
  * Performance summary
* **My Trainer**

  * Trainer info + message button
* **Track Progress**

  * Weight chart
  * Calories burned graph
* **Payment**

  * Current plan
  * History table
  * Renew button
* **Chat**

  * Trainer interaction

---

## 🌐 REST API Endpoints

### Auth

* `POST /api/auth/login` – Authenticate and return token
* `POST /api/auth/signup` – Register user
* `GET /api/auth/profile` – Get user info (JWT required)

### Users

* `GET /api/users/` – Admin only
* `PATCH /api/users/:id/assign-trainer` – Admin only

### Workouts

* `GET /api/workouts/user/:id` – Get workout plan for user
* `POST /api/workouts/user/:id` – Trainer creates/updates

### Diet

* `GET /api/diet/user/:id` – Get diet plan
* `POST /api/diet/user/:id` – Trainer assigns

### Performance

* `POST /api/performance/log` – User logs performance
* `GET /api/performance/user/:id` – Get logs

### Subscription

* `GET /api/subscription/:userId` – View current plan
* `POST /api/subscription/:userId/pay` – Create new payment

### Chat

* `GET /api/chat/:withUserId` – Fetch chat history
* `POST /api/chat/send` – Send new message

---

## 🧲 Suggestions for Phase 1 Development

1. **Auth Flow**

   * Signup, login, JWT handling
2. **Role-Based Routing**

   * Redirect to proper dashboard based on role
3. **User Dashboard**

   * Show workout/diet
   * Performance log
4. **Trainer Tools**

   * Create routines, assign diet
5. **Admin Tools**

   * Assign trainers
   * Payment logs
6. **Chat Module**

   * Socket.io implementation
   * Chat UI integration

---

Let me know if you want:

* Flutter BLoC structure for this
* MongoDB models
* Auth guards/middleware
* REST or GraphQL style backend
* Admin panel in Flutter Web or separate React app

* `GET /api/workouts/user/:id` – Get workout plan for user
* `POST /api/workouts/user/:id` – Trainer creates/updates

### Diet

* `GET /api/diet/user/:id` – Get diet plan
* `POST /api/diet/user/:id` – Trainer assigns

### Performance

* `POST /api/performance/log` – User logs performance
* `GET /api/performance/user/:id` – Get logs

### Subscription

* `GET /api/subscription/:userId` – View current plan
* `POST /api/subscription/:userId/pay` – Create new payment

### Chat

* `GET /api/chat/:withUserId` – Fetch chat history
* `POST /api/chat/send` – Send new message

---

## 🧲 Suggestions for Phase 1 Development

1. **Auth Flow**

   * Signup, login, JWT handling
2. **Role-Based Routing**

   * Redirect to proper dashboard based on role
3. **User Dashboard**

   * Show workout/diet
   * Performance log
4. **Trainer Tools**

   * Create routines, assign diet
5. **Admin Tools**

   * Assign trainers
   * Payment logs
6. **Chat Module**

   * Socket.io implementation
   * Chat UI integration

---

Let me know if you want:

* Flutter BLoC structure for this
* MongoDB models
* Auth guards/middleware
* REST or GraphQL style backend
* Admin panel in Flutter Web or separate React app
# 🏋️ Gym Management Flutter App - Full Feature & Flow Design

---

## ✨ Overview

A Flutter-based mobile app with role-based dashboards for **Admin**, **Trainer**, and **User**. The backend is powered by **Express.js + TypeScript** and **MongoDB** for scalable, document-driven flexibility. The app offers gym management, workout planning, user tracking, and communication features.

---

## 🛠️ Technology Stack

* **Frontend:** Flutter

  * Material Design Widgets
  * flutter\_bloc for state management
  * flutter\_chat\_ui for chat feature
  * fl\_chart for visual tracking

* **State Management:** flutter\_bloc

  * AuthBloc
  * UserBloc
  * TrainerBloc
  * AdminBloc

* **Backend:** Node.js (Express) + TypeScript

  * REST API
  * Socket.io for real-time chat
  * JWT-based authentication

* **Database:** MongoDB

  * Mongoose ODM
  * Role-based document modeling

* **Authentication:** JWT with Role-based Access

  * Middleware for route protection
  * Refresh token mechanism (optional in v2)

* **Realtime Chat:** Socket.IO

  * Private messaging between user and trainer
  * Chat history persistence

---

## 🌐 Roles & Functional Scope

### ✉️ Common Features

* **Authentication:** Secure login/signup with validations
* **Role-based Routing:** Redirect user based on assigned role
* **Profile View & Edit:** Change profile image, contact info, password
* **Chat Support:** Real-time communication using chat UI
* **Logout:** Token-based session termination

### 👨‍🏋️ User Flow (Gym Member)

* Register account (with optional referral code or plan)
* Log in and land on user dashboard
* View assigned trainer info and initiate chat
* Daily view of:

  * Exercise routine (day-wise)
  * Diet plan (meal-wise)
* Log performance:

  * Weight updates
  * Calories burned
  * Notes
* Visual graphs for weight/calories over time
* View subscription info and renewal history
* Push notifications for plan updates, chat replies, diet/workout changes

### 👩‍🏋️ Trainer Flow

* Log in and land on trainer dashboard
* View list of assigned users
* Assign or update workout plan for each user:

  * Day-wise routine
  * Exercise notes or links to YouTube videos
* Assign or update diet plan per user:

  * Meal breakdown (Breakfast, Lunch, Dinner)
  * Nutrition info (optional)
* View user progress charts
* Chat directly with each user
* Track last activity or interaction time for each user

### 🧑‍💼 Admin Flow

* Admin login with credentials (email/password)
* Access dashboard:

  * Total users, trainers, subscriptions
  * Revenue tracking
* Manage user list:

  * View all users
  * Assign/replace trainer
  * View subscription status
  * View user health goals
* Manage payments:

  * View all payment records
  * Filter by method, user, date
  * Export to CSV/Excel
* View trainer activity (last login, assigned users count)

---

## 📁 Backend MongoDB Data Model Design

### 1. User

```ts
interface User {
  _id: ObjectId,
  name: string,
  email: string,
  password: string,
  role: 'user' | 'trainer' | 'admin',
  profileImage?: string,
  trainerId?: ObjectId,
  healthGoals: string,
  subscription: Subscription,
  performance: PerformanceLog[],
  createdAt: Date,
  updatedAt: Date
}
```

* Auth users based on role
* Used by Admin to assign trainers
* Trainer can access `healthGoals`

### 2. Trainer

```ts
interface Trainer {
  _id: ObjectId,
  name: string,
  email: string,
  password: string,
  assignedUsers: ObjectId[],
  profileImage?: string,
  createdAt: Date,
  updatedAt: Date
}
```

* Trainers have multiple users
* Used in reporting and chat pairing

### 3. WorkoutRoutine

```ts
interface WorkoutRoutine {
  _id: ObjectId,
  userId: ObjectId,
  days: [
    {
      day: string,
      exercises: string[],
    }
  ],
  createdBy: ObjectId,
  createdAt: Date
}
```

* One routine per user per week
* Trainer-defined

### 4. DietPlan

```ts
interface DietPlan {
  _id: ObjectId,
  userId: ObjectId,
  dayWiseDiet: [
    {
      day: string,
      meals: string[],
    }
  ],
  createdBy: ObjectId,
  createdAt: Date
}
```

* Meal structure defined by trainer

### 5. Subscription

```ts
interface Subscription {
  isActive: boolean,
  startDate: Date,
  endDate: Date,
  paymentMethod: 'UPI' | 'Card' | 'Cash',
  amountPaid: number
}
```

* Directly embedded in user object for faster access

### 6. PaymentHistory

```ts
interface PaymentHistory {
  _id: ObjectId,
  userId: ObjectId,
  amount: number,
  method: 'UPI' | 'Card' | 'Cash',
  date: Date,
  remarks?: string
}
```

* Used for reports and admin views

### 7. PerformanceLog

```ts
interface PerformanceLog {
  date: Date,
  weight: number,
  caloriesBurned: number,
  notes?: string
}
```

* Added by user
* Visualized in performance screen

### 8. Chat

```ts
interface ChatMessage {
  _id: ObjectId,
  from: ObjectId,
  to: ObjectId,
  message: string,
  timestamp: Date,
  read: boolean
}
```

* Managed via WebSockets
* Shown in chat history screen

---

## 🛍️ Admin UI Flow

* **Dashboard**

  * Cards showing total users, trainers
  * Pie chart for payment methods
* **Customer List**

  * Search + filter (by trainer, status)
  * Click to view profile
* **Assign Trainer**

  * Dropdown select + assign action
* **Payment History**

  * Table view
  * Export/Download CSV
* **Trainer View**

  * List of trainers with assigned users count

---

## 🏋️ Trainer UI Flow

* **Dashboard**

  * Summary cards
  * Chart showing user engagement
* **Assigned Users**

  * List view
  * Tap to open user details
* **Create/Update Workout**

  * Form per day
  * Add notes/video link
* **Create/Update Diet**

  * Form for each meal per day
* **View Progress**

  * Charts
* **Chat**

  * Real-time conversation with users

---

## 🧜 User UI Flow

* **Dashboard**

  * Current diet plan
  * Today's exercise list (checkbox to mark done)
  * Performance summary
* **My Trainer**

  * Trainer info + message button
* **Track Progress**

  * Weight chart
  * Calories burned graph
* **Payment**

  * Current plan
  * History table
  * Renew button
* **Chat**

  * Trainer interaction

---

## 🌐 REST API Endpoints

### Auth

* `POST /api/auth/login` – Authenticate and return token
* `POST /api/auth/signup` – Register user
* `GET /api/auth/profile` – Get user info (JWT required)

### Users

* `GET /api/users/` – Admin only
* `PATCH /api/users/:id/assign-trainer` – Admin only

### Workouts

* `GET /api/workouts/user/:id` – Get workout plan for user
* `POST /api/workouts/user/:id` – Trainer creates/updates

### Diet

* `GET /api/diet/user/:id` – Get diet plan
* `POST /api/diet/user/:id` – Trainer assigns

### Performance

* `POST /api/performance/log` – User logs performance
* `GET /api/performance/user/:id` – Get logs

### Subscription

* `GET /api/subscription/:userId` – View current plan
* `POST /api/subscription/:userId/pay` – Create new payment

### Chat

* `GET /api/chat/:withUserId` – Fetch chat history
* `POST /api/chat/send` – Send new message

---

## 🧲 Suggestions for Phase 1 Development

1. **Auth Flow**

   * Signup, login, JWT handling
2. **Role-Based Routing**

   * Redirect to proper dashboard based on role
3. **User Dashboard**

   * Show workout/diet
   * Performance log
4. **Trainer Tools**

   * Create routines, assign diet
5. **Admin Tools**

   * Assign trainers
   * Payment logs
6. **Chat Module**

   * Socket.io implementation
   * Chat UI integration

---

Let me know if you want:

* Flutter BLoC structure for this
* MongoDB models
* Auth guards/middleware
* REST or GraphQL style backend
* Admin panel in Flutter Web or separate React app
