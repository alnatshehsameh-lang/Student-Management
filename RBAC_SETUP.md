# Role-Based Access Control (RBAC) Implementation Guide

## Overview
This application implements a 3-tier role-based access control system:

1. **Admin** - Full access to everything
2. **Manager** - Almost full access (can view/edit all data across the system)
3. **Supervisor** - Restricted access (only their assigned classes/groups)

## Database Schema Changes

### 1. Update Users Table
Add a `role` column to the `Users` table:

```sql
-- Add role column to Users table
ALTER TABLE public."Users" 
ADD COLUMN role text DEFAULT 'supervisor' CHECK (role IN ('admin', 'manager', 'supervisor'));

-- Set existing admin user
UPDATE public."Users" SET role = 'admin' WHERE username = 'admin';

-- Create index for performance
CREATE INDEX idx_users_role ON public."Users"(role);
```

### 2. Update Managers Table (for Supervisor Assignments)
The existing `Managers` table already has the required fields:
- `User_id` - references Users table
- `Class_id` - assigned class
- `Group_id` - assigned group
- `Type_id` - assigned type

## Row Level Security (RLS) Policies

### Enable RLS on all tables:

```sql
-- Enable RLS
ALTER TABLE public."Students" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."Attendance_Tadabur" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."Attendance_Sard" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."Classes" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."Groups" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."Types" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."Managers" ENABLE ROW LEVEL SECURITY;
```

### Create RLS Policies:

```sql
-- Students table: Admin/Manager see all, Supervisor sees only their assigned students
CREATE POLICY "users_select_students" ON public."Students"
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public."Users" u
      WHERE u.id = auth.uid()::integer
      AND (
        u.role IN ('admin', 'manager')
        OR EXISTS (
          SELECT 1 FROM public."Managers" m
          WHERE m."User_id" = u.id
          AND (
            m."Class_id" = "Students"."Class_id"
            OR m."Class_id" IS NULL
          )
          AND (
            m."Group_id" = "Students"."Group_id"
            OR m."Group_id" IS NULL
          )
          AND (
            m."Type_id" = "Students"."Type_id"
            OR m."Type_id" IS NULL
          )
        )
      )
    )
  );

-- Students insert/update/delete: Admin/Manager can do all, Supervisor can only for their classes
CREATE POLICY "users_insert_students" ON public."Students"
  FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public."Users" u
      WHERE u.id = auth.uid()::integer
      AND (
        u.role IN ('admin', 'manager')
        OR EXISTS (
          SELECT 1 FROM public."Managers" m
          WHERE m."User_id" = u.id
          AND m."Class_id" = "Students"."Class_id"
          AND (m."Group_id" = "Students"."Group_id" OR m."Group_id" IS NULL)
          AND (m."Type_id" = "Students"."Type_id" OR m."Type_id" IS NULL)
        )
      )
    )
  );

CREATE POLICY "users_update_students" ON public."Students"
  FOR UPDATE
  USING (
    EXISTS (
      SELECT 1 FROM public."Users" u
      WHERE u.id = auth.uid()::integer
      AND (
        u.role IN ('admin', 'manager')
        OR EXISTS (
          SELECT 1 FROM public."Managers" m
          WHERE m."User_id" = u.id
          AND m."Class_id" = "Students"."Class_id"
          AND (m."Group_id" = "Students"."Group_id" OR m."Group_id" IS NULL)
          AND (m."Type_id" = "Students"."Type_id" OR m."Type_id" IS NULL)
        )
      )
    )
  );

CREATE POLICY "users_delete_students" ON public."Students"
  FOR DELETE
  USING (
    EXISTS (
      SELECT 1 FROM public."Users" u
      WHERE u.id = auth.uid()::integer
      AND u.role IN ('admin', 'manager')
    )
  );

-- Attendance tables: Similar to Students
CREATE POLICY "users_select_attendance_tadabur" ON public."Attendance_Tadabur"
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public."Users" u
      WHERE u.id = auth.uid()::integer
      AND (
        u.role IN ('admin', 'manager')
        OR EXISTS (
          SELECT 1 FROM public."Managers" m
          JOIN public."Students" s ON s.id = "Attendance_Tadabur"."Student_id"
          WHERE m."User_id" = u.id
          AND (m."Class_id" = s."Class_id" OR m."Class_id" IS NULL)
          AND (m."Group_id" = s."Group_id" OR m."Group_id" IS NULL)
          AND (m."Type_id" = s."Type_id" OR m."Type_id" IS NULL)
        )
      )
    )
  );

CREATE POLICY "users_insert_attendance_tadabur" ON public."Attendance_Tadabur"
  FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public."Users" u
      WHERE u.id = auth.uid()::integer
      AND (
        u.role IN ('admin', 'manager')
        OR EXISTS (
          SELECT 1 FROM public."Managers" m
          JOIN public."Students" s ON s.id = "Attendance_Tadabur"."Student_id"
          WHERE m."User_id" = u.id
          AND m."Class_id" = s."Class_id"
          AND (m."Group_id" = s."Group_id" OR m."Group_id" IS NULL)
          AND (m."Type_id" = s."Type_id" OR m."Type_id" IS NULL)
        )
      )
    )
  );

-- Repeat for Attendance_Sard
CREATE POLICY "users_select_attendance_sard" ON public."Attendance_Sard"
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public."Users" u
      WHERE u.id = auth.uid()::integer
      AND (
        u.role IN ('admin', 'manager')
        OR EXISTS (
          SELECT 1 FROM public."Managers" m
          JOIN public."Students" s ON s.id = "Attendance_Sard"."Student_id"
          WHERE m."User_id" = u.id
          AND (m."Class_id" = s."Class_id" OR m."Class_id" IS NULL)
          AND (m."Group_id" = s."Group_id" OR m."Group_id" IS NULL)
          AND (m."Type_id" = s."Type_id" OR m."Type_id" IS NULL)
        )
      )
    )
  );

CREATE POLICY "users_insert_attendance_sard" ON public."Attendance_Sard"
  FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM public."Users" u
      WHERE u.id = auth.uid()::integer
      AND (
        u.role IN ('admin', 'manager')
        OR EXISTS (
          SELECT 1 FROM public."Managers" m
          JOIN public."Students" s ON s.id = "Attendance_Sard"."Student_id"
          WHERE m."User_id" = u.id
          AND m."Class_id" = s."Class_id"
          AND (m."Group_id" = s."Group_id" OR m."Group_id" IS NULL)
          AND (m."Type_id" = s."Type_id" OR m."Type_id" IS NULL)
        )
      )
    )
  );

-- Lookup tables: Everyone can read, only Admin/Manager can modify
CREATE POLICY "users_select_classes" ON public."Classes"
  FOR SELECT
  USING (true);

CREATE POLICY "users_modify_classes" ON public."Classes"
  FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM public."Users" u
      WHERE u.id = auth.uid()::integer
      AND u.role IN ('admin', 'manager')
    )
  );

CREATE POLICY "users_select_groups" ON public."Groups"
  FOR SELECT
  USING (true);

CREATE POLICY "users_modify_groups" ON public."Groups"
  FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM public."Users" u
      WHERE u.id = auth.uid()::integer
      AND u.role IN ('admin', 'manager')
    )
  );

CREATE POLICY "users_select_types" ON public."Types"
  FOR SELECT
  USING (true);

CREATE POLICY "users_modify_types" ON public."Types"
  FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM public."Users" u
      WHERE u.id = auth.uid()::integer
      AND u.role IN ('admin', 'manager')
    )
  );

-- Managers table: Admin can manage, users can view their own
CREATE POLICY "users_select_managers" ON public."Managers"
  FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public."Users" u
      WHERE u.id = auth.uid()::integer
      AND (u.role = 'admin' OR u.id = "Managers"."User_id")
    )
  );

CREATE POLICY "users_modify_managers" ON public."Managers"
  FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM public."Users" u
      WHERE u.id = auth.uid()::integer
      AND u.role = 'admin'
    )
  );
```

## Flutter Implementation

### 1. UserSession Model
Already updated with `UserRole` enum and access control methods.

### 2. Login Flow
Update login to fetch user role from Users table.

### 3. Navigation Guards
Implement role-based navigation in main.dart to hide/show menu items.

### 4. Query Filtering
All screens should use the UserSession methods to filter queries:
- `hasFullAccess` - no filtering needed
- `hasRestrictions` - apply Class_id/Group_id/Type_id filters

### 5. UI Controls
- Hide admin-only buttons for non-admins
- Hide manager features for supervisors
- Show "Access Denied" messages when appropriate

## Security Best Practices

1. **Backend First**: RLS policies enforce security at database level
2. **Query Filtering**: Flutter app filters queries for performance
3. **UI Guards**: Hide unauthorized features in UI
4. **Validation**: Backend validates all operations via RLS
5. **Least Privilege**: Supervisors see only their data by default

## Creating Users

### Admin User (already exists):
- Username: `admin`
- Password: `admin`
- Role: `admin`

### Create Manager User:
```sql
INSERT INTO public."Users" (username, email, password, role)
VALUES ('manager1', 'manager1@example.com', 'password123', 'manager');
```

### Create Supervisor User:
```sql
-- 1. Create user
INSERT INTO public."Users" (username, email, password, role)
VALUES ('supervisor1', 'supervisor1@example.com', 'password123', 'supervisor')
RETURNING id;

-- 2. Assign to class/group (use returned id)
INSERT INTO public."Managers" ("User_id", "Class_id", "Group_id", "Type_id")
VALUES (3, 1, 1, NULL);  -- Replace 3 with actual user id
```

## Testing Checklist

- [ ] Admin can see all students/classes/attendance
- [ ] Manager can see all students/classes/attendance
- [ ] Supervisor can only see their assigned class students
- [ ] Supervisor cannot modify other classes
- [ ] RLS blocks unauthorized queries at database level
- [ ] UI properly hides unauthorized features
- [ ] Role changes take effect immediately
