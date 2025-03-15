import { supabase } from './supabase';

interface DashboardStats {
  reservations: {
    active: number;
    pending: number;
    total_customers: number;
    returning_customers: number;
    avg_rental_days: number;
    total_revenue: number;
  };
  equipment: {
    total: number;
    out_of_stock: number;
    low_stock: number;
  };
  maintenance: {
    planned: number;
    ongoing: number;
  };
  popular_equipment: Array<{
    id: string;
    name: string;
    count: number;
  }>;
}

interface PipelineData {
  columns: Array<{
    id: string;
    title: string;
    reservations: Array<{
      id: string;
      customer: {
        id: string;
        first_name: string;
        last_name: string;
        email: string;
        phone: string;
      };
      dates: {
        start: string;
        end: string;
      };
      total_price: number;
      items: Array<{
        id: string;
        equipment_name: string;
        quantity: number;
      }>;
    }>;
  }>;
}

interface CRMStats {
  contacts: {
    leads: number;
    customers: number;
    inactive: number;
    avg_lead_score: number;
    active_last_30_days: number;
  };
  tasks: {
    today: number;
    pending: number;
    completed: number;
  };
}

export const getDashboardStats = async (dateRange: string = '30days'): Promise<DashboardStats> => {
  const { data, error } = await supabase
    .rpc('get_admin_dashboard_stats', { p_date_range: dateRange });

  if (error) throw error;
  return data;
};

export const getPipelineData = async (
  dateRange: string = '30days',
  statuses: string[] = ['pending', 'confirmed', 'completed']
): Promise<PipelineData> => {
  const { data, error } = await supabase
    .rpc('get_admin_pipeline_data', {
      p_date_range: dateRange,
      p_status: statuses
    });

  if (error) throw error;
  return data;
};

export const getCRMStats = async (): Promise<CRMStats> => {
  const { data, error } = await supabase
    .rpc('get_admin_crm_stats');

  if (error) throw error;
  return data;
};

export const getReservationDetails = async (reservationId: string) => {
  const { data, error } = await supabase
    .from('admin_reservations_view')
    .select('*')
    .eq('id', reservationId)
    .single();

  if (error) throw error;
  return data;
};

// Subskrypcja do zmian w czasie rzeczywistym
export const subscribeToAdminUpdates = (
  onReservationUpdate: (data: any) => void,
  onEquipmentUpdate: (data: any) => void,
  onMaintenanceUpdate: (data: any) => void
) => {
  const channel = supabase.channel('admin_updates')
    .on(
      'postgres_changes',
      { event: '*', schema: 'public', table: 'reservations' },
      (payload) => onReservationUpdate(payload)
    )
    .on(
      'postgres_changes',
      { event: '*', schema: 'public', table: 'equipment' },
      (payload) => onEquipmentUpdate(payload)
    )
    .on(
      'postgres_changes',
      { event: '*', schema: 'public', table: 'maintenance_logs' },
      (payload) => onMaintenanceUpdate(payload)
    )
    .subscribe();

  return () => {
    channel.unsubscribe();
  };
};