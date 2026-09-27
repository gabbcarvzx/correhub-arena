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
      activity_events: {
        Row: {
          actor_user_id: string | null
          created_at: string
          dedupe_key: string
          entity_id: string
          entity_type: string
          event_type: string
          group_id: string | null
          id: string
          metadata: Json
        }
        Insert: {
          actor_user_id?: string | null
          created_at?: string
          dedupe_key: string
          entity_id: string
          entity_type: string
          event_type: string
          group_id?: string | null
          id?: string
          metadata?: Json
        }
        Update: {
          actor_user_id?: string | null
          created_at?: string
          dedupe_key?: string
          entity_id?: string
          entity_type?: string
          event_type?: string
          group_id?: string | null
          id?: string
          metadata?: Json
        }
        Relationships: [
          {
            foreignKeyName: "activity_events_group_id_fkey"
            columns: ["group_id"]
            isOneToOne: false
            referencedRelation: "groups"
            referencedColumns: ["id"]
          },
        ]
      }
      app_settings: {
        Row: {
          created_at: string
          id: string
          launch_city_id: string
          updated_at: string
        }
        Insert: {
          created_at?: string
          id: string
          launch_city_id: string
          updated_at?: string
        }
        Update: {
          created_at?: string
          id?: string
          launch_city_id?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "app_settings_launch_city_id_fkey"
            columns: ["launch_city_id"]
            isOneToOne: false
            referencedRelation: "cities"
            referencedColumns: ["id"]
          },
        ]
      }
      cities: {
        Row: {
          country_code: string
          created_at: string
          id: string
          is_active: boolean
          name: string
          slug: string
          state_code: string
          timezone: string
          updated_at: string
        }
        Insert: {
          country_code: string
          created_at?: string
          id?: string
          is_active?: boolean
          name: string
          slug: string
          state_code: string
          timezone: string
          updated_at?: string
        }
        Update: {
          country_code?: string
          created_at?: string
          id?: string
          is_active?: boolean
          name?: string
          slug?: string
          state_code?: string
          timezone?: string
          updated_at?: string
        }
        Relationships: []
      }
      comments: {
        Row: {
          body: string
          created_at: string
          deleted_at: string | null
          id: string
          post_id: string
          updated_at: string
          user_id: string | null
        }
        Insert: {
          body: string
          created_at?: string
          deleted_at?: string | null
          id?: string
          post_id: string
          updated_at?: string
          user_id?: string | null
        }
        Update: {
          body?: string
          created_at?: string
          deleted_at?: string | null
          id?: string
          post_id?: string
          updated_at?: string
          user_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "comments_post_id_fkey"
            columns: ["post_id"]
            isOneToOne: false
            referencedRelation: "posts"
            referencedColumns: ["id"]
          },
        ]
      }
      group_follows: {
        Row: {
          created_at: string
          group_id: string
          user_id: string
        }
        Insert: {
          created_at?: string
          group_id: string
          user_id: string
        }
        Update: {
          created_at?: string
          group_id?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "group_follows_group_id_fkey"
            columns: ["group_id"]
            isOneToOne: false
            referencedRelation: "groups"
            referencedColumns: ["id"]
          },
        ]
      }
      group_members: {
        Row: {
          group_id: string
          joined_at: string | null
          role: string
          status: string
          updated_at: string
          user_id: string
        }
        Insert: {
          group_id: string
          joined_at?: string | null
          role: string
          status: string
          updated_at?: string
          user_id: string
        }
        Update: {
          group_id?: string
          joined_at?: string | null
          role?: string
          status?: string
          updated_at?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "group_members_group_id_fkey"
            columns: ["group_id"]
            isOneToOne: false
            referencedRelation: "groups"
            referencedColumns: ["id"]
          },
        ]
      }
      groups: {
        Row: {
          approved_at: string | null
          approved_by: string | null
          avatar_url: string | null
          city_id: string
          cover_url: string | null
          created_at: string
          created_by: string | null
          description: string
          id: string
          join_policy: string
          name: string
          owner_user_id: string
          rejection_reason: string | null
          slug: string
          status: string
          suspended_at: string | null
          type: string
          updated_at: string
        }
        Insert: {
          approved_at?: string | null
          approved_by?: string | null
          avatar_url?: string | null
          city_id: string
          cover_url?: string | null
          created_at?: string
          created_by?: string | null
          description: string
          id?: string
          join_policy: string
          name: string
          owner_user_id: string
          rejection_reason?: string | null
          slug: string
          status?: string
          suspended_at?: string | null
          type: string
          updated_at?: string
        }
        Update: {
          approved_at?: string | null
          approved_by?: string | null
          avatar_url?: string | null
          city_id?: string
          cover_url?: string | null
          created_at?: string
          created_by?: string | null
          description?: string
          id?: string
          join_policy?: string
          name?: string
          owner_user_id?: string
          rejection_reason?: string | null
          slug?: string
          status?: string
          suspended_at?: string | null
          type?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "groups_city_id_fkey"
            columns: ["city_id"]
            isOneToOne: false
            referencedRelation: "cities"
            referencedColumns: ["id"]
          },
        ]
      }
      notifications: {
        Row: {
          actor_user_id: string | null
          created_at: string
          dedupe_key: string
          id: string
          read_at: string | null
          recipient_user_id: string
          target_id: string | null
          target_type: string
          type: string
        }
        Insert: {
          actor_user_id?: string | null
          created_at?: string
          dedupe_key: string
          id?: string
          read_at?: string | null
          recipient_user_id: string
          target_id?: string | null
          target_type: string
          type: string
        }
        Update: {
          actor_user_id?: string | null
          created_at?: string
          dedupe_key?: string
          id?: string
          read_at?: string | null
          recipient_user_id?: string
          target_id?: string | null
          target_type?: string
          type?: string
        }
        Relationships: []
      }
      post_likes: {
        Row: {
          created_at: string
          post_id: string
          user_id: string
        }
        Insert: {
          created_at?: string
          post_id: string
          user_id: string
        }
        Update: {
          created_at?: string
          post_id?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "post_likes_post_id_fkey"
            columns: ["post_id"]
            isOneToOne: false
            referencedRelation: "posts"
            referencedColumns: ["id"]
          },
        ]
      }
      posts: {
        Row: {
          author_user_id: string | null
          body: string
          created_at: string
          deleted_at: string | null
          group_id: string | null
          id: string
          image_url: string | null
          updated_at: string
          visibility: string
        }
        Insert: {
          author_user_id?: string | null
          body: string
          created_at?: string
          deleted_at?: string | null
          group_id?: string | null
          id?: string
          image_url?: string | null
          updated_at?: string
          visibility: string
        }
        Update: {
          author_user_id?: string | null
          body?: string
          created_at?: string
          deleted_at?: string | null
          group_id?: string | null
          id?: string
          image_url?: string | null
          updated_at?: string
          visibility?: string
        }
        Relationships: [
          {
            foreignKeyName: "posts_group_id_fkey"
            columns: ["group_id"]
            isOneToOne: false
            referencedRelation: "groups"
            referencedColumns: ["id"]
          },
        ]
      }
      profiles: {
        Row: {
          avatar_url: string | null
          bio: string | null
          city_id: string | null
          created_at: string
          full_name: string | null
          id: string
          is_private: boolean
          onboarding_completed: boolean
          pace_seconds_per_km: number | null
          preferred_distance: string | null
          running_level: string | null
          updated_at: string
          username: string | null
        }
        Insert: {
          avatar_url?: string | null
          bio?: string | null
          city_id?: string | null
          created_at?: string
          full_name?: string | null
          id: string
          is_private?: boolean
          onboarding_completed?: boolean
          pace_seconds_per_km?: number | null
          preferred_distance?: string | null
          running_level?: string | null
          updated_at?: string
          username?: string | null
        }
        Update: {
          avatar_url?: string | null
          bio?: string | null
          city_id?: string | null
          created_at?: string
          full_name?: string | null
          id?: string
          is_private?: boolean
          onboarding_completed?: boolean
          pace_seconds_per_km?: number | null
          preferred_distance?: string | null
          running_level?: string | null
          updated_at?: string
          username?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "profiles_city_id_fkey"
            columns: ["city_id"]
            isOneToOne: false
            referencedRelation: "cities"
            referencedColumns: ["id"]
          },
        ]
      }
      run_participations: {
        Row: {
          id: string
          joined_at: string
          run_id: string
          status: string
          updated_at: string
          user_id: string | null
        }
        Insert: {
          id?: string
          joined_at?: string
          run_id: string
          status?: string
          updated_at?: string
          user_id?: string | null
        }
        Update: {
          id?: string
          joined_at?: string
          run_id?: string
          status?: string
          updated_at?: string
          user_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "run_participations_run_id_fkey"
            columns: ["run_id"]
            isOneToOne: false
            referencedRelation: "runs"
            referencedColumns: ["id"]
          },
        ]
      }
      run_series: {
        Row: {
          city_id: string
          created_at: string
          created_by: string | null
          description: string
          distance_meters: number
          ends_on: string | null
          generated_through: string | null
          group_id: string
          id: string
          level: string
          local_start_time: string
          location_text: string
          max_participants: number | null
          meeting_offset_minutes: number
          starts_on: string
          status: string
          timezone: string
          title: string
          updated_at: string
          visibility: string
          weekday: number
        }
        Insert: {
          city_id: string
          created_at?: string
          created_by?: string | null
          description: string
          distance_meters: number
          ends_on?: string | null
          generated_through?: string | null
          group_id: string
          id?: string
          level: string
          local_start_time: string
          location_text: string
          max_participants?: number | null
          meeting_offset_minutes?: number
          starts_on: string
          status?: string
          timezone: string
          title: string
          updated_at?: string
          visibility: string
          weekday: number
        }
        Update: {
          city_id?: string
          created_at?: string
          created_by?: string | null
          description?: string
          distance_meters?: number
          ends_on?: string | null
          generated_through?: string | null
          group_id?: string
          id?: string
          level?: string
          local_start_time?: string
          location_text?: string
          max_participants?: number | null
          meeting_offset_minutes?: number
          starts_on?: string
          status?: string
          timezone?: string
          title?: string
          updated_at?: string
          visibility?: string
          weekday?: number
        }
        Relationships: [
          {
            foreignKeyName: "run_series_city_id_fkey"
            columns: ["city_id"]
            isOneToOne: false
            referencedRelation: "cities"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "run_series_group_id_fkey"
            columns: ["group_id"]
            isOneToOne: false
            referencedRelation: "groups"
            referencedColumns: ["id"]
          },
        ]
      }
      runs: {
        Row: {
          cancellation_reason: string | null
          cancelled_at: string | null
          city_id: string
          created_at: string
          created_by: string | null
          description: string
          distance_meters: number
          group_id: string
          id: string
          level: string
          location_text: string
          max_participants: number | null
          meeting_time: string | null
          occurrence_date: string | null
          series_id: string | null
          starts_at: string
          status: string
          title: string
          updated_at: string
          visibility: string
        }
        Insert: {
          cancellation_reason?: string | null
          cancelled_at?: string | null
          city_id: string
          created_at?: string
          created_by?: string | null
          description: string
          distance_meters: number
          group_id: string
          id?: string
          level: string
          location_text: string
          max_participants?: number | null
          meeting_time?: string | null
          occurrence_date?: string | null
          series_id?: string | null
          starts_at: string
          status?: string
          title: string
          updated_at?: string
          visibility: string
        }
        Update: {
          cancellation_reason?: string | null
          cancelled_at?: string | null
          city_id?: string
          created_at?: string
          created_by?: string | null
          description?: string
          distance_meters?: number
          group_id?: string
          id?: string
          level?: string
          location_text?: string
          max_participants?: number | null
          meeting_time?: string | null
          occurrence_date?: string | null
          series_id?: string | null
          starts_at?: string
          status?: string
          title?: string
          updated_at?: string
          visibility?: string
        }
        Relationships: [
          {
            foreignKeyName: "runs_city_id_fkey"
            columns: ["city_id"]
            isOneToOne: false
            referencedRelation: "cities"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "runs_group_id_fkey"
            columns: ["group_id"]
            isOneToOne: false
            referencedRelation: "groups"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "runs_series_group_city_fkey"
            columns: ["series_id", "group_id", "city_id"]
            isOneToOne: false
            referencedRelation: "run_series"
            referencedColumns: ["id", "group_id", "city_id"]
          },
        ]
      }
      user_follows: {
        Row: {
          created_at: string
          followed_id: string
          follower_id: string
        }
        Insert: {
          created_at?: string
          followed_id: string
          follower_id: string
        }
        Update: {
          created_at?: string
          followed_id?: string
          follower_id?: string
        }
        Relationships: []
      }
    }
    Views: {
      profile_directory: {
        Row: {
          avatar_url: string | null
          bio: string | null
          city_id: string | null
          city_name: string | null
          city_slug: string | null
          country_code: string | null
          created_at: string | null
          full_name: string | null
          id: string | null
          pace_seconds_per_km: number | null
          preferred_distance: string | null
          running_level: string | null
          state_code: string | null
          username: string | null
        }
        Relationships: [
          {
            foreignKeyName: "profiles_city_id_fkey"
            columns: ["city_id"]
            isOneToOne: false
            referencedRelation: "cities"
            referencedColumns: ["id"]
          },
        ]
      }
    }
    Functions: {
      accept_group_owner_transfer: {
        Args: { target_transfer_id: string }
        Returns: undefined
      }
      approve_group_member: {
        Args: { target_group_id: string; target_user_id: string }
        Returns: undefined
      }
      approve_group_request: {
        Args: { target_group_id: string }
        Returns: undefined
      }
      block_group_member: {
        Args: { target_group_id: string; target_user_id: string }
        Returns: undefined
      }
      cancel_group_owner_transfer: {
        Args: { target_transfer_id: string }
        Returns: undefined
      }
      demote_group_admin: {
        Args: { target_group_id: string; target_user_id: string }
        Returns: undefined
      }
      discover_profiles: {
        Args: {
          after_id?: string
          after_username?: string
          filter_city_id?: string
          page_size?: number
          search_query?: string
        }
        Returns: {
          avatar_url: string
          bio: string
          city_id: string
          city_name: string
          city_slug: string
          country_code: string
          created_at: string
          full_name: string
          id: string
          pace_seconds_per_km: number
          preferred_distance: string
          running_level: string
          state_code: string
          username: string
          visibility: string
        }[]
      }
      ensure_current_account_foundation: {
        Args: never
        Returns: {
          account_status: string
          onboarding_completed: boolean
        }[]
      }
      get_current_account_state: {
        Args: never
        Returns: {
          account_status: string
          onboarding_completed: boolean
        }[]
      }
      get_current_group_relation: {
        Args: { target_group_id: string }
        Returns: {
          joined_at: string
          relation_role: string
          relation_status: string
        }[]
      }
      get_group_by_slug: {
        Args: { target_slug: string }
        Returns: {
          approved_at: string
          avatar_url: string
          city_id: string
          city_name: string
          cover_url: string
          created_at: string
          description: string
          group_type: string
          id: string
          is_owner: boolean
          join_policy: string
          name: string
          owner_user_id: string
          slug: string
          status: string
          updated_at: string
        }[]
      }
      get_group_owner_transfer: {
        Args: { target_group_id: string }
        Returns: {
          created_at: string
          effective_status: string
          expires_at: string
          from_user_id: string
          group_id: string
          to_user_id: string
          transfer_id: string
        }[]
      }
      get_group_review: {
        Args: { target_group_id: string }
        Returns: {
          avatar_url: string
          city_id: string
          city_name: string
          cover_url: string
          created_at: string
          created_by: string
          description: string
          group_type: string
          id: string
          join_policy: string
          name: string
          owner_user_id: string
          rejection_reason: string
          slug: string
          status: string
          updated_at: string
        }[]
      }
      get_profile_by_username: {
        Args: { target_username: string }
        Returns: {
          avatar_url: string
          bio: string
          city_id: string
          city_name: string
          city_slug: string
          country_code: string
          created_at: string
          full_name: string
          id: string
          pace_seconds_per_km: number
          preferred_distance: string
          running_level: string
          state_code: string
          username: string
          visibility: string
        }[]
      }
      initiate_group_owner_transfer: {
        Args: { target_group_id: string; target_user_id: string }
        Returns: string
      }
      join_group: { Args: { target_group_id: string }; Returns: string }
      leave_group: { Args: { target_group_id: string }; Returns: undefined }
      list_group_members: {
        Args: {
          after_user_id?: string
          after_username?: string
          page_size?: number
          requested_status?: string
          target_group_id: string
        }
        Returns: {
          avatar_url: string
          full_name: string
          joined_at: string
          member_role: string
          member_status: string
          user_id: string
          username: string
          visibility: string
        }[]
      }
      list_group_review_queue: {
        Args: {
          after_created_at?: string
          after_id?: string
          page_size?: number
        }
        Returns: {
          city_id: string
          city_name: string
          created_at: string
          created_by: string
          description: string
          group_type: string
          id: string
          join_policy: string
          name: string
          owner_user_id: string
          slug: string
          status: string
          updated_at: string
        }[]
      }
      list_my_groups: {
        Args: {
          after_id?: string
          after_updated_at?: string
          page_size?: number
        }
        Returns: {
          avatar_url: string
          group_type: string
          id: string
          join_policy: string
          name: string
          rejection_reason: string
          relation_role: string
          relation_status: string
          slug: string
          status: string
          updated_at: string
        }[]
      }
      list_profile_connections: {
        Args: {
          after_id?: string
          after_username?: string
          connection_direction: string
          page_size?: number
          target_username: string
        }
        Returns: {
          avatar_url: string
          bio: string
          city_id: string
          city_name: string
          city_slug: string
          country_code: string
          created_at: string
          full_name: string
          id: string
          pace_seconds_per_km: number
          preferred_distance: string
          running_level: string
          state_code: string
          username: string
          visibility: string
        }[]
      }
      promote_group_admin: {
        Args: { target_group_id: string; target_user_id: string }
        Returns: undefined
      }
      reject_group_member_request: {
        Args: { target_group_id: string; target_user_id: string }
        Returns: undefined
      }
      reject_group_request: {
        Args: { reason: string; target_group_id: string }
        Returns: undefined
      }
      request_group: {
        Args: {
          requested_city_id: string
          requested_description: string
          requested_join_policy: string
          requested_name: string
          requested_slug: string
          requested_type: string
        }
        Returns: string
      }
      restore_group: {
        Args: { reason: string; target_group_id: string }
        Returns: undefined
      }
      resubmit_group: { Args: { target_group_id: string }; Returns: undefined }
      suspend_group: {
        Args: { reason: string; target_group_id: string }
        Returns: undefined
      }
      update_group_profile: {
        Args: {
          requested_city_id: string
          requested_description: string
          requested_join_policy: string
          requested_name: string
          requested_slug: string
          requested_type: string
          target_group_id: string
        }
        Returns: undefined
      }
    }
    Enums: {
      [_ in never]: never
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
    Enums: {},
  },
} as const
