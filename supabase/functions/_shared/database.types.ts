export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[]

export type Database = {
  graphql_public: {
    Tables: {
      [_ in never]: never
    }
    Views: {
      [_ in never]: never
    }
    Functions: {
      graphql: {
        Args: {
          extensions?: Json
          operationName?: string
          query?: string
          variables?: Json
        }
        Returns: Json
      }
    }
    Enums: {
      [_ in never]: never
    }
    CompositeTypes: {
      [_ in never]: never
    }
  }
  public: {
    Tables: {
      admins: {
        Row: {
          active: boolean
          created_at: string
          id: string
          name: string
          role: Database["public"]["Enums"]["admin_role"]
          updated_at: string
          user_id: string
        }
        Insert: {
          active?: boolean
          created_at?: string
          id?: string
          name: string
          role: Database["public"]["Enums"]["admin_role"]
          updated_at?: string
          user_id: string
        }
        Update: {
          active?: boolean
          created_at?: string
          id?: string
          name?: string
          role?: Database["public"]["Enums"]["admin_role"]
          updated_at?: string
          user_id?: string
        }
        Relationships: []
      }
      app_config: {
        Row: {
          created_at: string
          id: string
          key: string
          updated_at: string
          value: Json
        }
        Insert: {
          created_at?: string
          id?: string
          key: string
          updated_at?: string
          value: Json
        }
        Update: {
          created_at?: string
          id?: string
          key?: string
          updated_at?: string
          value?: Json
        }
        Relationships: []
      }
      audit_log: {
        Row: {
          action: string
          actor_id: string | null
          actor_type: string
          after: Json | null
          at: string
          before: Json | null
          id: string
          row_id: string | null
          table_name: string
        }
        Insert: {
          action: string
          actor_id?: string | null
          actor_type: string
          after?: Json | null
          at?: string
          before?: Json | null
          id?: string
          row_id?: string | null
          table_name: string
        }
        Update: {
          action?: string
          actor_id?: string | null
          actor_type?: string
          after?: Json | null
          at?: string
          before?: Json | null
          id?: string
          row_id?: string | null
          table_name?: string
        }
        Relationships: []
      }
      beds: {
        Row: {
          bed_label: string
          created_at: string
          id: string
          room_unit_id: string
          updated_at: string
        }
        Insert: {
          bed_label: string
          created_at?: string
          id?: string
          room_unit_id: string
          updated_at?: string
        }
        Update: {
          bed_label?: string
          created_at?: string
          id?: string
          room_unit_id?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "beds_room_unit_id_fkey"
            columns: ["room_unit_id"]
            isOneToOne: false
            referencedRelation: "room_units"
            referencedColumns: ["id"]
          },
        ]
      }
      blocks: {
        Row: {
          created_at: string
          display_order: number
          floor_id: string
          id: string
          name: string
          updated_at: string
        }
        Insert: {
          created_at?: string
          display_order?: number
          floor_id: string
          id?: string
          name: string
          updated_at?: string
        }
        Update: {
          created_at?: string
          display_order?: number
          floor_id?: string
          id?: string
          name?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "blocks_floor_id_fkey"
            columns: ["floor_id"]
            isOneToOne: false
            referencedRelation: "floors"
            referencedColumns: ["id"]
          },
        ]
      }
      bookings: {
        Row: {
          bed_id: string
          billing_cycle: Database["public"]["Enums"]["billing_cycle"]
          created_at: string
          created_tenant_id: string | null
          full_name: string | null
          held_expires_at: string
          id: string
          onboarding_charges_paise: number
          otp_verified_at: string | null
          phone: string
          property_id: string
          razorpay_order_id: string | null
          razorpay_payment_id: string | null
          recorded_by: string | null
          rent_paise: number
          room_unit_id: string
          security_deposit_paise: number
          source: string
          status: Database["public"]["Enums"]["booking_status"]
          total_amount_paise: number
          updated_at: string
        }
        Insert: {
          bed_id: string
          billing_cycle: Database["public"]["Enums"]["billing_cycle"]
          created_at?: string
          created_tenant_id?: string | null
          full_name?: string | null
          held_expires_at: string
          id?: string
          onboarding_charges_paise: number
          otp_verified_at?: string | null
          phone: string
          property_id: string
          razorpay_order_id?: string | null
          razorpay_payment_id?: string | null
          recorded_by?: string | null
          rent_paise: number
          room_unit_id: string
          security_deposit_paise: number
          source?: string
          status?: Database["public"]["Enums"]["booking_status"]
          total_amount_paise: number
          updated_at?: string
        }
        Update: {
          bed_id?: string
          billing_cycle?: Database["public"]["Enums"]["billing_cycle"]
          created_at?: string
          created_tenant_id?: string | null
          full_name?: string | null
          held_expires_at?: string
          id?: string
          onboarding_charges_paise?: number
          otp_verified_at?: string | null
          phone?: string
          property_id?: string
          razorpay_order_id?: string | null
          razorpay_payment_id?: string | null
          recorded_by?: string | null
          rent_paise?: number
          room_unit_id?: string
          security_deposit_paise?: number
          source?: string
          status?: Database["public"]["Enums"]["booking_status"]
          total_amount_paise?: number
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "bookings_bed_id_fkey"
            columns: ["bed_id"]
            isOneToOne: false
            referencedRelation: "beds"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "bookings_created_tenant_id_fkey"
            columns: ["created_tenant_id"]
            isOneToOne: false
            referencedRelation: "tenants"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "bookings_property_id_fkey"
            columns: ["property_id"]
            isOneToOne: false
            referencedRelation: "properties"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "bookings_recorded_by_fkey"
            columns: ["recorded_by"]
            isOneToOne: false
            referencedRelation: "admins"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "bookings_room_unit_id_fkey"
            columns: ["room_unit_id"]
            isOneToOne: false
            referencedRelation: "room_units"
            referencedColumns: ["id"]
          },
        ]
      }
      consents: {
        Row: {
          accepted_at: string
          app_version: string
          created_at: string
          device_info: Json
          id: string
          policy_version: string
          tenant_id: string
          typed_full_name: string
          updated_at: string
        }
        Insert: {
          accepted_at?: string
          app_version: string
          created_at?: string
          device_info: Json
          id?: string
          policy_version: string
          tenant_id: string
          typed_full_name: string
          updated_at?: string
        }
        Update: {
          accepted_at?: string
          app_version?: string
          created_at?: string
          device_info?: Json
          id?: string
          policy_version?: string
          tenant_id?: string
          typed_full_name?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "consents_tenant_id_fkey"
            columns: ["tenant_id"]
            isOneToOne: false
            referencedRelation: "tenants"
            referencedColumns: ["id"]
          },
        ]
      }
      dues: {
        Row: {
          amount_paise: number
          created_at: string
          created_by: string
          description: string | null
          due_date: string
          id: string
          status: Database["public"]["Enums"]["due_status"]
          tenant_id: string
          type: Database["public"]["Enums"]["due_type"]
          updated_at: string
        }
        Insert: {
          amount_paise: number
          created_at?: string
          created_by: string
          description?: string | null
          due_date: string
          id?: string
          status?: Database["public"]["Enums"]["due_status"]
          tenant_id: string
          type: Database["public"]["Enums"]["due_type"]
          updated_at?: string
        }
        Update: {
          amount_paise?: number
          created_at?: string
          created_by?: string
          description?: string | null
          due_date?: string
          id?: string
          status?: Database["public"]["Enums"]["due_status"]
          tenant_id?: string
          type?: Database["public"]["Enums"]["due_type"]
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "dues_created_by_fkey"
            columns: ["created_by"]
            isOneToOne: false
            referencedRelation: "admins"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "dues_tenant_id_fkey"
            columns: ["tenant_id"]
            isOneToOne: false
            referencedRelation: "tenants"
            referencedColumns: ["id"]
          },
        ]
      }
      electricity_bill_splits: {
        Row: {
          bill_id: string
          created_at: string
          due_id: string
          id: string
          tenant_id: string
        }
        Insert: {
          bill_id: string
          created_at?: string
          due_id: string
          id?: string
          tenant_id: string
        }
        Update: {
          bill_id?: string
          created_at?: string
          due_id?: string
          id?: string
          tenant_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "electricity_bill_splits_bill_id_fkey"
            columns: ["bill_id"]
            isOneToOne: false
            referencedRelation: "electricity_bills"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "electricity_bill_splits_due_id_fkey"
            columns: ["due_id"]
            isOneToOne: true
            referencedRelation: "dues"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "electricity_bill_splits_tenant_id_fkey"
            columns: ["tenant_id"]
            isOneToOne: false
            referencedRelation: "tenants"
            referencedColumns: ["id"]
          },
        ]
      }
      electricity_bills: {
        Row: {
          billing_period: string
          created_at: string
          created_by: string
          id: string
          room_unit_id: string
          total_amount_paise: number
          updated_at: string
        }
        Insert: {
          billing_period: string
          created_at?: string
          created_by: string
          id?: string
          room_unit_id: string
          total_amount_paise: number
          updated_at?: string
        }
        Update: {
          billing_period?: string
          created_at?: string
          created_by?: string
          id?: string
          room_unit_id?: string
          total_amount_paise?: number
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "electricity_bills_created_by_fkey"
            columns: ["created_by"]
            isOneToOne: false
            referencedRelation: "admins"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "electricity_bills_room_unit_id_fkey"
            columns: ["room_unit_id"]
            isOneToOne: false
            referencedRelation: "room_units"
            referencedColumns: ["id"]
          },
        ]
      }
      fines: {
        Row: {
          amount_paise: number
          created_at: string
          created_by: string
          due_id: string
          ends_on: string
          id: string
          starts_on: string
          updated_at: string
        }
        Insert: {
          amount_paise: number
          created_at?: string
          created_by: string
          due_id: string
          ends_on: string
          id?: string
          starts_on: string
          updated_at?: string
        }
        Update: {
          amount_paise?: number
          created_at?: string
          created_by?: string
          due_id?: string
          ends_on?: string
          id?: string
          starts_on?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "fines_created_by_fkey"
            columns: ["created_by"]
            isOneToOne: false
            referencedRelation: "admins"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "fines_due_id_fkey"
            columns: ["due_id"]
            isOneToOne: false
            referencedRelation: "dues"
            referencedColumns: ["id"]
          },
        ]
      }
      floors: {
        Row: {
          created_at: string
          display_order: number
          id: string
          name: string
          property_id: string
          updated_at: string
        }
        Insert: {
          created_at?: string
          display_order?: number
          id?: string
          name: string
          property_id: string
          updated_at?: string
        }
        Update: {
          created_at?: string
          display_order?: number
          id?: string
          name?: string
          property_id?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "floors_property_id_fkey"
            columns: ["property_id"]
            isOneToOne: false
            referencedRelation: "properties"
            referencedColumns: ["id"]
          },
        ]
      }
      kyc_submissions: {
        Row: {
          aadhaar_last4: string
          aadhaar_path: string
          created_at: string
          id: string
          rejection_reason: string | null
          reviewed_at: string | null
          reviewed_by: string | null
          selfie_path: string
          status: Database["public"]["Enums"]["kyc_status"]
          submitted_at: string
          tenant_id: string
          updated_at: string
        }
        Insert: {
          aadhaar_last4: string
          aadhaar_path: string
          created_at?: string
          id?: string
          rejection_reason?: string | null
          reviewed_at?: string | null
          reviewed_by?: string | null
          selfie_path: string
          status?: Database["public"]["Enums"]["kyc_status"]
          submitted_at?: string
          tenant_id: string
          updated_at?: string
        }
        Update: {
          aadhaar_last4?: string
          aadhaar_path?: string
          created_at?: string
          id?: string
          rejection_reason?: string | null
          reviewed_at?: string | null
          reviewed_by?: string | null
          selfie_path?: string
          status?: Database["public"]["Enums"]["kyc_status"]
          submitted_at?: string
          tenant_id?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "kyc_submissions_reviewed_by_fkey"
            columns: ["reviewed_by"]
            isOneToOne: false
            referencedRelation: "admins"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "kyc_submissions_tenant_id_fkey"
            columns: ["tenant_id"]
            isOneToOne: true
            referencedRelation: "tenants"
            referencedColumns: ["id"]
          },
        ]
      }
      payments: {
        Row: {
          amount_paise: number
          created_at: string
          due_id: string
          id: string
          method: string | null
          paid_at: string | null
          razorpay_order_id: string | null
          razorpay_payment_id: string | null
          recorded_by: string | null
          source: Database["public"]["Enums"]["payment_source"]
          status: Database["public"]["Enums"]["payment_status"]
          tenant_id: string
          updated_at: string
        }
        Insert: {
          amount_paise: number
          created_at?: string
          due_id: string
          id?: string
          method?: string | null
          paid_at?: string | null
          razorpay_order_id?: string | null
          razorpay_payment_id?: string | null
          recorded_by?: string | null
          source: Database["public"]["Enums"]["payment_source"]
          status?: Database["public"]["Enums"]["payment_status"]
          tenant_id: string
          updated_at?: string
        }
        Update: {
          amount_paise?: number
          created_at?: string
          due_id?: string
          id?: string
          method?: string | null
          paid_at?: string | null
          razorpay_order_id?: string | null
          razorpay_payment_id?: string | null
          recorded_by?: string | null
          source?: Database["public"]["Enums"]["payment_source"]
          status?: Database["public"]["Enums"]["payment_status"]
          tenant_id?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "payments_due_id_fkey"
            columns: ["due_id"]
            isOneToOne: false
            referencedRelation: "dues"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "payments_recorded_by_fkey"
            columns: ["recorded_by"]
            isOneToOne: false
            referencedRelation: "admins"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "payments_tenant_id_fkey"
            columns: ["tenant_id"]
            isOneToOne: false
            referencedRelation: "tenants"
            referencedColumns: ["id"]
          },
        ]
      }
      phone_check_attempts: {
        Row: {
          created_at: string
          id: string
          ip: unknown
          phone: string
        }
        Insert: {
          created_at?: string
          id?: string
          ip: unknown
          phone: string
        }
        Update: {
          created_at?: string
          id?: string
          ip?: unknown
          phone?: string
        }
        Relationships: []
      }
      pricing_plans: {
        Row: {
          active: boolean
          capacity: number
          created_at: string
          id: string
          onboarding_charges_paise: number
          property_id: string
          rent_monthly_paise: number
          rent_yearly_paise: number
          security_deposit_paise: number
          updated_at: string
        }
        Insert: {
          active?: boolean
          capacity: number
          created_at?: string
          id?: string
          onboarding_charges_paise: number
          property_id: string
          rent_monthly_paise: number
          rent_yearly_paise: number
          security_deposit_paise: number
          updated_at?: string
        }
        Update: {
          active?: boolean
          capacity?: number
          created_at?: string
          id?: string
          onboarding_charges_paise?: number
          property_id?: string
          rent_monthly_paise?: number
          rent_yearly_paise?: number
          security_deposit_paise?: number
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "pricing_plans_property_id_fkey"
            columns: ["property_id"]
            isOneToOne: false
            referencedRelation: "properties"
            referencedColumns: ["id"]
          },
        ]
      }
      properties: {
        Row: {
          address: string
          created_at: string
          id: string
          name: string
          self_signup_enabled: boolean
          updated_at: string
        }
        Insert: {
          address: string
          created_at?: string
          id?: string
          name: string
          self_signup_enabled?: boolean
          updated_at?: string
        }
        Update: {
          address?: string
          created_at?: string
          id?: string
          name?: string
          self_signup_enabled?: boolean
          updated_at?: string
        }
        Relationships: []
      }
      room_units: {
        Row: {
          capacity: number
          created_at: string
          id: string
          room_id: string
          updated_at: string
        }
        Insert: {
          capacity: number
          created_at?: string
          id?: string
          room_id: string
          updated_at?: string
        }
        Update: {
          capacity?: number
          created_at?: string
          id?: string
          room_id?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "room_units_room_id_fkey"
            columns: ["room_id"]
            isOneToOne: false
            referencedRelation: "rooms"
            referencedColumns: ["id"]
          },
        ]
      }
      rooms: {
        Row: {
          block_id: string | null
          created_at: string
          id: string
          property_id: string
          room_number: string
          updated_at: string
        }
        Insert: {
          block_id?: string | null
          created_at?: string
          id?: string
          property_id: string
          room_number: string
          updated_at?: string
        }
        Update: {
          block_id?: string | null
          created_at?: string
          id?: string
          property_id?: string
          room_number?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "rooms_block_id_fkey"
            columns: ["block_id"]
            isOneToOne: false
            referencedRelation: "blocks"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "rooms_property_id_fkey"
            columns: ["property_id"]
            isOneToOne: false
            referencedRelation: "properties"
            referencedColumns: ["id"]
          },
        ]
      }
      tenants: {
        Row: {
          billing_cycle: Database["public"]["Enums"]["billing_cycle"]
          created_at: string
          fcm_token: string | null
          firebase_uid: string | null
          full_name: string
          id: string
          kyc_status: Database["public"]["Enums"]["kyc_status"]
          monthly_rent_paise: number
          move_in_date: string
          move_out_date: string | null
          phone: string
          property_id: string
          room_unit_id: string
          status: Database["public"]["Enums"]["tenant_status"]
          updated_at: string
        }
        Insert: {
          billing_cycle?: Database["public"]["Enums"]["billing_cycle"]
          created_at?: string
          fcm_token?: string | null
          firebase_uid?: string | null
          full_name: string
          id?: string
          kyc_status?: Database["public"]["Enums"]["kyc_status"]
          monthly_rent_paise: number
          move_in_date: string
          move_out_date?: string | null
          phone: string
          property_id: string
          room_unit_id: string
          status?: Database["public"]["Enums"]["tenant_status"]
          updated_at?: string
        }
        Update: {
          billing_cycle?: Database["public"]["Enums"]["billing_cycle"]
          created_at?: string
          fcm_token?: string | null
          firebase_uid?: string | null
          full_name?: string
          id?: string
          kyc_status?: Database["public"]["Enums"]["kyc_status"]
          monthly_rent_paise?: number
          move_in_date?: string
          move_out_date?: string | null
          phone?: string
          property_id?: string
          room_unit_id?: string
          status?: Database["public"]["Enums"]["tenant_status"]
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "tenants_property_id_fkey"
            columns: ["property_id"]
            isOneToOne: false
            referencedRelation: "properties"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "tenants_room_unit_id_fkey"
            columns: ["room_unit_id"]
            isOneToOne: false
            referencedRelation: "room_units"
            referencedColumns: ["id"]
          },
        ]
      }
      webhook_events: {
        Row: {
          created_at: string
          event_id: string
          id: string
          payload: Json
          processed_at: string | null
          provider: string
          updated_at: string
        }
        Insert: {
          created_at?: string
          event_id: string
          id?: string
          payload: Json
          processed_at?: string | null
          provider: string
          updated_at?: string
        }
        Update: {
          created_at?: string
          event_id?: string
          id?: string
          payload?: Json
          processed_at?: string | null
          provider?: string
          updated_at?: string
        }
        Relationships: []
      }
      whatsapp_invoice_log: {
        Row: {
          attempted_at: string
          booking_id: string
          created_at: string
          error_message: string | null
          id: string
          provider_message_id: string | null
          status: string
          updated_at: string
        }
        Insert: {
          attempted_at?: string
          booking_id: string
          created_at?: string
          error_message?: string | null
          id?: string
          provider_message_id?: string | null
          status?: string
          updated_at?: string
        }
        Update: {
          attempted_at?: string
          booking_id?: string
          created_at?: string
          error_message?: string | null
          id?: string
          provider_message_id?: string | null
          status?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "whatsapp_invoice_log_booking_id_fkey"
            columns: ["booking_id"]
            isOneToOne: false
            referencedRelation: "bookings"
            referencedColumns: ["id"]
          },
        ]
      }
    }
    Views: {
      [_ in never]: never
    }
    Functions: {
      _firebase_project_id: { Args: never; Returns: string }
      _jwt_sub_as_uuid: { Args: never; Returns: string }
      current_tenant_id: { Args: never; Returns: string }
      delete_abandoned_bookings: { Args: never; Returns: undefined }
      is_admin: { Args: never; Returns: boolean }
      is_owner: { Args: never; Returns: boolean }
      is_tenant: { Args: never; Returns: boolean }
      recalculate_electricity_bill_split: {
        Args: { p_bill_id: string }
        Returns: undefined
      }
      tenant_can_access_main_app: { Args: never; Returns: boolean }
      tenant_is_active: { Args: never; Returns: boolean }
    }
    Enums: {
      admin_role: "owner" | "staff"
      billing_cycle: "monthly" | "yearly"
      booking_status:
        | "hold"
        | "otp_verified"
        | "payment_pending"
        | "paid"
        | "payment_failed"
        | "expired"
        | "cancelled"
        | "refunded"
      due_status: "unpaid" | "paid" | "cancelled"
      due_type: "rent" | "deposit" | "electricity" | "other"
      kyc_status: "not_started" | "submitted" | "approved" | "rejected"
      payment_source: "razorpay" | "manual"
      payment_status: "created" | "paid" | "failed" | "refunded"
      tenant_status: "active" | "moved_out"
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
  graphql_public: {
    Enums: {},
  },
  public: {
    Enums: {
      admin_role: ["owner", "staff"],
      billing_cycle: ["monthly", "yearly"],
      booking_status: [
        "hold",
        "otp_verified",
        "payment_pending",
        "paid",
        "payment_failed",
        "expired",
        "cancelled",
        "refunded",
      ],
      due_status: ["unpaid", "paid", "cancelled"],
      due_type: ["rent", "deposit", "electricity", "other"],
      kyc_status: ["not_started", "submitted", "approved", "rejected"],
      payment_source: ["razorpay", "manual"],
      payment_status: ["created", "paid", "failed", "refunded"],
      tenant_status: ["active", "moved_out"],
    },
  },
} as const

