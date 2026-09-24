export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[]

export type Database = {
  public: {
    Tables: {
      academic_years: {
        Row: {
          created_at: string
          ends_on: string
          id: string
          label: string
          school_id: string
          starts_on: string
          status: string
          updated_at: string
        }
        Insert: {
          created_at?: string
          ends_on: string
          id?: string
          label: string
          school_id: string
          starts_on: string
          status?: string
          updated_at?: string
        }
        Update: {
          created_at?: string
          ends_on?: string
          id?: string
          label?: string
          school_id?: string
          starts_on?: string
          status?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "academic_years_school_id_fkey"
            columns: ["school_id"]
            isOneToOne: false
            referencedRelation: "schools"
            referencedColumns: ["id"]
          },
        ]
      }
      audit_events: {
        Row: {
          action: string
          actor_role: Database["public"]["Enums"]["school_role"]
          actor_user_id: string
          after_summary: Json | null
          before_summary: Json | null
          created_at: string
          id: string
          reason: string | null
          request_id: string | null
          school_id: string
          target_id: string
          target_type: string
        }
        Insert: {
          action: string
          actor_role: Database["public"]["Enums"]["school_role"]
          actor_user_id: string
          after_summary?: Json | null
          before_summary?: Json | null
          created_at?: string
          id?: string
          reason?: string | null
          request_id?: string | null
          school_id: string
          target_id: string
          target_type: string
        }
        Update: {
          action?: string
          actor_role?: Database["public"]["Enums"]["school_role"]
          actor_user_id?: string
          after_summary?: Json | null
          before_summary?: Json | null
          created_at?: string
          id?: string
          reason?: string | null
          request_id?: string | null
          school_id?: string
          target_id?: string
          target_type?: string
        }
        Relationships: [
          {
            foreignKeyName: "audit_events_school_id_fkey"
            columns: ["school_id"]
            isOneToOne: false
            referencedRelation: "schools"
            referencedColumns: ["id"]
          },
        ]
      }
      classes: {
        Row: {
          created_at: string
          grade_level: string | null
          id: string
          name: string
          school_id: string
          section: string | null
          status: string
          updated_at: string
        }
        Insert: {
          created_at?: string
          grade_level?: string | null
          id?: string
          name: string
          school_id: string
          section?: string | null
          status?: string
          updated_at?: string
        }
        Update: {
          created_at?: string
          grade_level?: string | null
          id?: string
          name?: string
          school_id?: string
          section?: string | null
          status?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "classes_school_id_fkey"
            columns: ["school_id"]
            isOneToOne: false
            referencedRelation: "schools"
            referencedColumns: ["id"]
          },
        ]
      }
      courses: {
        Row: {
          academic_year_id: string
          class_id: string
          created_at: string
          id: string
          school_id: string
          status: string
          subject_id: string
          title: string
          updated_at: string
        }
        Insert: {
          academic_year_id: string
          class_id: string
          created_at?: string
          id?: string
          school_id: string
          status?: string
          subject_id: string
          title: string
          updated_at?: string
        }
        Update: {
          academic_year_id?: string
          class_id?: string
          created_at?: string
          id?: string
          school_id?: string
          status?: string
          subject_id?: string
          title?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "courses_school_id_academic_year_id_fkey"
            columns: ["school_id", "academic_year_id"]
            isOneToOne: false
            referencedRelation: "academic_years"
            referencedColumns: ["school_id", "id"]
          },
          {
            foreignKeyName: "courses_school_id_class_id_fkey"
            columns: ["school_id", "class_id"]
            isOneToOne: false
            referencedRelation: "classes"
            referencedColumns: ["school_id", "id"]
          },
          {
            foreignKeyName: "courses_school_id_fkey"
            columns: ["school_id"]
            isOneToOne: false
            referencedRelation: "schools"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "courses_school_id_subject_id_fkey"
            columns: ["school_id", "subject_id"]
            isOneToOne: false
            referencedRelation: "subjects"
            referencedColumns: ["school_id", "id"]
          },
        ]
      }
      membership_roles: {
        Row: {
          created_at: string
          granted_at: string
          membership_id: string
          revoked_at: string | null
          role: Database["public"]["Enums"]["school_role"]
          school_id: string
          status: string
          updated_at: string
        }
        Insert: {
          created_at?: string
          granted_at?: string
          membership_id: string
          revoked_at?: string | null
          role: Database["public"]["Enums"]["school_role"]
          school_id: string
          status?: string
          updated_at?: string
        }
        Update: {
          created_at?: string
          granted_at?: string
          membership_id?: string
          revoked_at?: string | null
          role?: Database["public"]["Enums"]["school_role"]
          school_id?: string
          status?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "membership_roles_school_id_membership_id_fkey"
            columns: ["school_id", "membership_id"]
            isOneToOne: false
            referencedRelation: "school_memberships"
            referencedColumns: ["school_id", "id"]
          },
        ]
      }
      profiles: {
        Row: {
          created_at: string
          display_name: string | null
          id: string
          updated_at: string
        }
        Insert: {
          created_at?: string
          display_name?: string | null
          id: string
          updated_at?: string
        }
        Update: {
          created_at?: string
          display_name?: string | null
          id?: string
          updated_at?: string
        }
        Relationships: []
      }
      school_memberships: {
        Row: {
          created_at: string
          disabled_at: string | null
          id: string
          joined_at: string
          school_id: string
          status: string
          updated_at: string
          user_id: string
        }
        Insert: {
          created_at?: string
          disabled_at?: string | null
          id?: string
          joined_at?: string
          school_id: string
          status?: string
          updated_at?: string
          user_id: string
        }
        Update: {
          created_at?: string
          disabled_at?: string | null
          id?: string
          joined_at?: string
          school_id?: string
          status?: string
          updated_at?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "school_memberships_school_id_fkey"
            columns: ["school_id"]
            isOneToOne: false
            referencedRelation: "schools"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "school_memberships_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      schools: {
        Row: {
          created_at: string
          id: string
          name: string
          status: string
          updated_at: string
        }
        Insert: {
          created_at?: string
          id?: string
          name: string
          status?: string
          updated_at?: string
        }
        Update: {
          created_at?: string
          id?: string
          name?: string
          status?: string
          updated_at?: string
        }
        Relationships: []
      }
      student_enrollments: {
        Row: {
          academic_year_id: string
          class_id: string
          created_at: string
          enrolled_at: string
          enrolled_by: string
          id: string
          school_id: string
          status: string
          student_membership_id: string
          unenrolled_at: string | null
          updated_at: string
        }
        Insert: {
          academic_year_id: string
          class_id: string
          created_at?: string
          enrolled_at?: string
          enrolled_by: string
          id?: string
          school_id: string
          status?: string
          student_membership_id: string
          unenrolled_at?: string | null
          updated_at?: string
        }
        Update: {
          academic_year_id?: string
          class_id?: string
          created_at?: string
          enrolled_at?: string
          enrolled_by?: string
          id?: string
          school_id?: string
          status?: string
          student_membership_id?: string
          unenrolled_at?: string | null
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "student_enrollments_school_id_academic_year_id_fkey"
            columns: ["school_id", "academic_year_id"]
            isOneToOne: false
            referencedRelation: "academic_years"
            referencedColumns: ["school_id", "id"]
          },
          {
            foreignKeyName: "student_enrollments_school_id_class_id_fkey"
            columns: ["school_id", "class_id"]
            isOneToOne: false
            referencedRelation: "classes"
            referencedColumns: ["school_id", "id"]
          },
          {
            foreignKeyName: "student_enrollments_school_id_enrolled_by_fkey"
            columns: ["school_id", "enrolled_by"]
            isOneToOne: false
            referencedRelation: "school_memberships"
            referencedColumns: ["school_id", "id"]
          },
          {
            foreignKeyName: "student_enrollments_school_id_student_membership_id_fkey"
            columns: ["school_id", "student_membership_id"]
            isOneToOne: false
            referencedRelation: "school_memberships"
            referencedColumns: ["school_id", "id"]
          },
        ]
      }
      subjects: {
        Row: {
          code: string | null
          created_at: string
          id: string
          name: string
          school_id: string
          status: string
          updated_at: string
        }
        Insert: {
          code?: string | null
          created_at?: string
          id?: string
          name: string
          school_id: string
          status?: string
          updated_at?: string
        }
        Update: {
          code?: string | null
          created_at?: string
          id?: string
          name?: string
          school_id?: string
          status?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "subjects_school_id_fkey"
            columns: ["school_id"]
            isOneToOne: false
            referencedRelation: "schools"
            referencedColumns: ["id"]
          },
        ]
      }
      teacher_assignments: {
        Row: {
          assigned_at: string
          assigned_by: string
          course_id: string
          created_at: string
          id: string
          revoked_at: string | null
          school_id: string
          status: string
          teacher_membership_id: string
          updated_at: string
        }
        Insert: {
          assigned_at?: string
          assigned_by: string
          course_id: string
          created_at?: string
          id?: string
          revoked_at?: string | null
          school_id: string
          status?: string
          teacher_membership_id: string
          updated_at?: string
        }
        Update: {
          assigned_at?: string
          assigned_by?: string
          course_id?: string
          created_at?: string
          id?: string
          revoked_at?: string | null
          school_id?: string
          status?: string
          teacher_membership_id?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "teacher_assignments_school_id_assigned_by_fkey"
            columns: ["school_id", "assigned_by"]
            isOneToOne: false
            referencedRelation: "school_memberships"
            referencedColumns: ["school_id", "id"]
          },
          {
            foreignKeyName: "teacher_assignments_school_id_course_id_fkey"
            columns: ["school_id", "course_id"]
            isOneToOne: false
            referencedRelation: "courses"
            referencedColumns: ["school_id", "id"]
          },
          {
            foreignKeyName: "teacher_assignments_school_id_teacher_membership_id_fkey"
            columns: ["school_id", "teacher_membership_id"]
            isOneToOne: false
            referencedRelation: "school_memberships"
            referencedColumns: ["school_id", "id"]
          },
        ]
      }
    }
    Views: {
      [_ in never]: never
    }
    Functions: {
      admin_assign_teacher: {
        Args: {
          p_actor_user_id: string
          p_course_id: string
          p_request_id?: string
          p_school_id: string
          p_teacher_membership_id: string
        }
        Returns: string
      }
      admin_create_academic_year: {
        Args: {
          p_actor_user_id: string
          p_ends_on: string
          p_label: string
          p_request_id?: string
          p_school_id: string
          p_starts_on: string
        }
        Returns: string
      }
      admin_create_class: {
        Args: {
          p_actor_user_id: string
          p_grade_level?: string
          p_name: string
          p_request_id?: string
          p_school_id: string
          p_section?: string
        }
        Returns: string
      }
      admin_create_course: {
        Args: {
          p_academic_year_id: string
          p_actor_user_id: string
          p_class_id: string
          p_request_id?: string
          p_school_id: string
          p_subject_id: string
          p_title: string
        }
        Returns: string
      }
      admin_create_subject: {
        Args: {
          p_actor_user_id: string
          p_code?: string
          p_name: string
          p_request_id?: string
          p_school_id: string
        }
        Returns: string
      }
      admin_enroll_student: {
        Args: {
          p_academic_year_id: string
          p_actor_user_id: string
          p_class_id: string
          p_request_id?: string
          p_school_id: string
          p_student_membership_id: string
        }
        Returns: string
      }
      admin_revoke_teacher_assignment: {
        Args: {
          p_actor_user_id: string
          p_assignment_id: string
          p_request_id?: string
          p_school_id: string
        }
        Returns: string
      }
      admin_set_membership_role: {
        Args: {
          p_actor_user_id: string
          p_request_id?: string
          p_role: Database["public"]["Enums"]["school_role"]
          p_school_id: string
          p_status?: string
          p_user_id: string
        }
        Returns: string
      }
      admin_set_membership_status: {
        Args: {
          p_actor_user_id: string
          p_membership_id: string
          p_request_id?: string
          p_school_id: string
          p_status: string
        }
        Returns: string
      }
      admin_unenroll_student: {
        Args: {
          p_actor_user_id: string
          p_enrollment_id: string
          p_request_id?: string
          p_school_id: string
        }
        Returns: string
      }
    }
    Enums: {
      school_role: "student" | "teacher" | "admin"
    }
    CompositeTypes: {
      [_ in never]: never
    }
  }
}

type DatabaseWithoutInternals = Omit<Database, "__InternalSupabase">

type DefaultSchema = DatabaseWithoutInternals[Extract<keyof Database, "public">]

export type Tables<
  DefaultSchemaTableNameOrOptions extends
    | keyof (DefaultSchema["Tables"] & DefaultSchema["Views"])
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
        DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])
    : never) = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
      DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])[TableName] extends {
      Row: infer R
    }
    ? R
    : never
  : DefaultSchemaTableNameOrOptions extends keyof (DefaultSchema["Tables"] &
        DefaultSchema["Views"])
    ? (DefaultSchema["Tables"] &
        DefaultSchema["Views"])[DefaultSchemaTableNameOrOptions] extends {
        Row: infer R
      }
      ? R
      : never
    : never

export type TablesInsert<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never) = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Insert: infer I
    }
    ? I
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Insert: infer I
      }
      ? I
      : never
    : never

export type TablesUpdate<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never) = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Update: infer U
    }
    ? U
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Update: infer U
      }
      ? U
      : never
    : never

export type Enums<
  DefaultSchemaEnumNameOrOptions extends
    | keyof DefaultSchema["Enums"]
    | { schema: keyof DatabaseWithoutInternals },
  EnumName extends (DefaultSchemaEnumNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"]
    : never) = never,
> = DefaultSchemaEnumNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"][EnumName]
  : DefaultSchemaEnumNameOrOptions extends keyof DefaultSchema["Enums"]
    ? DefaultSchema["Enums"][DefaultSchemaEnumNameOrOptions]
    : never

export type CompositeTypes<
  PublicCompositeTypeNameOrOptions extends
    | keyof DefaultSchema["CompositeTypes"]
    | { schema: keyof DatabaseWithoutInternals },
  CompositeTypeName extends (PublicCompositeTypeNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"]
    : never) = never,
> = PublicCompositeTypeNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"][CompositeTypeName]
  : PublicCompositeTypeNameOrOptions extends keyof DefaultSchema["CompositeTypes"]
    ? DefaultSchema["CompositeTypes"][PublicCompositeTypeNameOrOptions]
    : never

export const Constants = {
  public: {
    Enums: {
      school_role: ["student", "teacher", "admin"],
    },
  },
} as const
