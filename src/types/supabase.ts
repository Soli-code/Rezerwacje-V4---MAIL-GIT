export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[]

export interface Database {
  public: {
    Tables: {
      profiles: {
        Row: {
          id: string
          created_at: string
          email: string
          full_name: string | null
          is_admin: boolean
        }
        Insert: {
          id: string
          created_at?: string
          email: string
          full_name?: string | null
          is_admin?: boolean
        }
        Update: {
          id?: string
          created_at?: string
          email?: string
          full_name?: string | null
          is_admin?: boolean
        }
      }
      // Dodaj tutaj inne tabele z Twojej bazy danych
    }
    Views: {
      [_ in never]: never
    }
    Functions: {
      [_ in never]: never
    }
    Enums: {
      [_ in never]: never
    }
  }
} 