# Sample Entity Relation

``` mermaid

erDiagram
    users ||--o{ user_profiles : has
    users ||--o{ trainer_profiles : has
    users ||--o{ exercise_logs : logs
    users ||--o{ diet_logs : logs
    users ||--o{ subscriptions : has
    users ||--o{ notifications : gets
    users ||--o{ chats : sends
    users ||--o{ chats : receives
    trainer_profiles ||--|{ exercise_library : defines
    user_profiles }o--|| users : assigned_trainer
```
